class Venta < ApplicationRecord
  self.table_name = "ventas"
  include CurrencyAware

  ISV_RATE = BigDecimal("0.15")

  belongs_to :cliente
  belongs_to :pre_factura, optional: true
  belongs_to :creado_por, class_name: "User", optional: true
  has_many :venta_items, dependent: :destroy, inverse_of: :venta
  has_many :paquetes, -> { distinct }, through: :venta_items
  has_many :pagos, dependent: :restrict_with_error
  has_many :recibos, dependent: :restrict_with_error
  has_many :notas_debito,  dependent: :restrict_with_error
  has_many :notas_credito, dependent: :restrict_with_error
  has_one  :cotizacion, dependent: :nullify
  has_one  :financiamiento, dependent: :restrict_with_error

  accepts_nested_attributes_for :venta_items, allow_destroy: true

  ESTADOS = %w[proforma pendiente pagada anulada].freeze

  validates :numero, presence: true, uniqueness: { case_sensitive: false }
  validates :estado, presence: true, inclusion: { in: ESTADOS }

  before_validation :generate_numero, on: :create, if: -> { numero.blank? }
  before_save :calculate_totals

  scope :activas,        -> { where.not(estado: "anulada") }
  scope :pendientes,     -> { where(estado: "pendiente") }
  scope :pagadas,        -> { where(estado: "pagada") }
  scope :sin_proformas,  -> { where.not(estado: "proforma") }
  scope :proformas,      -> { where(estado: "proforma") }
  scope :recientes,  -> { order(created_at: :desc) }
  scope :by_cliente, ->(id) { where(cliente_id: id) }
  scope :by_estado,  ->(estado) { where(estado: estado) }
  scope :buscar, ->(term) {
    left_joins(:cliente).where(
      "ventas.numero ILIKE :q OR clientes.codigo ILIKE :q OR clientes.nombre ILIKE :q",
      q: "%#{sanitize_sql_like(term)}%"
    )
  }

  ESTADOS.each do |estado|
    define_method("#{estado}?") { self.estado == estado }
  end

  def save(**args, &block)
    super
  rescue ActiveRecord::RecordNotUnique => e
    raise unless new_record? && e.message.include?("numero") && (@_numero_retries ||= 0) < 3
    @_numero_retries += 1
    self.numero = nil
    generate_numero
    retry
  end

  def pagado_total
    pagos.where(estado: "completado").sum(:monto)
  end

  def total_ajustado
    total.to_d + notas_debito.emitidas.sum(:total).to_d - notas_credito.emitidas.sum(:total).to_d
  end

  def registrar_pago(monto:, metodo_pago:, user: nil, notas: nil)
    return nil if anulada? || pagada?

    monto_bd = BigDecimal(monto.to_s)
    return nil if monto_bd <= 0

    recibo = nil
    transaction do
      pago = pagos.create!(
        cliente: cliente,
        monto: monto_bd,
        metodo_pago: metodo_pago,
        moneda: moneda,
        estado: "completado",
        pagado_at: Time.current,
        notas: notas,
        registrado_por: user
      )

      apertura = AperturaCaja.del_dia
      pago.update!(apertura_caja: apertura) if apertura&.abierta?

      recibo = recibos.create!(
        pago: pago,
        cliente: cliente,
        monto: monto_bd,
        forma_pago: metodo_pago,
        moneda: moneda
      )

      nuevo_saldo = (saldo_pendiente.to_d - monto_bd)
      nuevo_saldo = BigDecimal("0") if nuevo_saldo < 0
      attrs = { saldo_pendiente: nuevo_saldo }

      if nuevo_saldo <= 0
        attrs[:estado] = "pagada"
        attrs[:pagada_at] = Time.current
      end
      update!(attrs)

      cliente.decrement!(:saldo_pendiente, monto_bd)

      if pagada?
        paquetes.reload.each { |p| p.update!(estado: "facturado") }
      end
    end

    # Fuera de la transaction: encola email si venta quedo pagada
    if pagada? && email_pagada_enviado_at.nil? &&
       cliente.email.present? && cliente.notificar_facturas?
      FacturaMailer.pagada(self, recibo).deliver_later
      update_column(:email_pagada_enviado_at, Time.current)
    end

    recibo
  end

  def anular!
    return false if anulada?
    return false if pagada?

    transaction do
      paquetes.reload.each do |p|
        p.update!(venta_id: nil, estado: "disponible_entrega")
      end
      if pre_factura
        pre_factura.update!(estado: "pendiente", facturado_at: nil)
      end
      cliente.decrement!(:saldo_pendiente, total) unless proforma?
      update!(estado: "anulada")
    end
    true
  end

  # Builds a Venta(proforma) with venta_items linked to paquetes, like PreFactura.build_from_paquetes.
  def self.build_proforma_from_paquetes(cliente, paquete_ids, user: nil, notas: nil)
    proforma = new(
      cliente: cliente,
      creado_por: user,
      estado: "proforma",
      moneda: "LPS",
      notas: notas
    )

    paquetes = cliente.paquetes.where(id: paquete_ids).includes(:tipo_envio)
    paquetes.each do |paquete|
      precio = cliente.categoria_precio&.precio_para(paquete.tipo_envio) ||
               paquete.tipo_envio&.precio_libra ||
               BigDecimal("0")
      peso = paquete.peso_cobrar || BigDecimal("0")
      subtotal = (BigDecimal(peso.to_s) * BigDecimal(precio.to_s)).round(2)

      proforma.venta_items.build(
        paquete: paquete,
        concepto: "Flete #{paquete.tipo_envio&.nombre || 'Paquete'} - #{paquete.guia}",
        peso_cobrar: peso,
        precio_libra: precio,
        subtotal: subtotal
      )
    end

    proforma
  end

  # Emits a proforma as a real factura: transitions paquetes to pre_facturado,
  # sets saldo_pendiente, and charges the client.
  def emitir_proforma!
    return false unless proforma?

    transaction do
      venta_items.includes(:paquete).each do |item|
        next unless item.paquete
        item.paquete.update!(venta_id: id, estado: "pre_facturado")
      end
      update!(estado: "pendiente", saldo_pendiente: total)
      cliente.increment!(:saldo_pendiente, total)
    end
    true
  end

  # Cancels a proforma, releasing any reserved paquetes.
  def anular_proforma!
    return false unless proforma?

    transaction do
      venta_items.includes(:paquete).each do |item|
        next unless item.paquete
        item.paquete.update!(venta_id: nil, estado: "disponible_entrega")
      end
      update!(estado: "anulada")
    end
    true
  end

  private

  def generate_numero
    next_number = (self.class.where("numero LIKE 'VT-%'")
                    .maximum(Arel.sql("CAST(SUBSTRING(numero FROM 4) AS INTEGER)")) || 0) + 1
    self.numero = "VT-#{next_number.to_s.rjust(6, '0')}"
  end

  def calculate_totals
    sub = venta_items.reject(&:marked_for_destruction?)
                     .sum { |i| i.subtotal.to_d }
    self.subtotal = sub
    self.impuesto = (sub * ISV_RATE).round(2)
    self.total    = (sub + impuesto).round(2)

    self.saldo_pendiente = total if new_record?
  end
end
