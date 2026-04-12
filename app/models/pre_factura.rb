class PreFactura < ApplicationRecord
  ISV_RATE = BigDecimal("0.15")

  belongs_to :cliente
  belongs_to :creado_por, class_name: "User", optional: true
  has_many :pre_factura_items, dependent: :destroy, inverse_of: :pre_factura
  has_many :paquetes, -> { distinct }, through: :pre_factura_items

  accepts_nested_attributes_for :pre_factura_items, allow_destroy: true

  ESTADOS = %w[creado pendiente facturado anulado].freeze

  validates :numero, presence: true, uniqueness: { case_sensitive: false }
  validates :estado, presence: true, inclusion: { in: ESTADOS }
  validates :moneda, presence: true

  before_validation :generate_numero, on: :create, if: -> { numero.blank? }
  before_save :calculate_totals

  scope :activas,    -> { where.not(estado: "anulado") }
  scope :pendientes, -> { where(estado: "pendiente") }
  scope :recientes,  -> { order(created_at: :desc) }
  scope :by_cliente, ->(id) { where(cliente_id: id) }
  scope :by_estado,  ->(estado) { where(estado: estado) }
  scope :buscar, ->(term) {
    left_joins(:cliente).where(
      "pre_facturas.numero ILIKE :q OR clientes.codigo ILIKE :q OR clientes.nombre ILIKE :q",
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

  def confirmar!
    return false unless creado?

    transaction do
      update!(estado: "pendiente", confirmado_at: Time.current)
      paquetes.reload.each { |p| p.update!(estado: "pre_facturado") }
    end
    true
  end

  attr_reader :nota_debito_auto

  def facturar!
    return false if facturado? || anulado?

    venta = nil
    @nota_debito_auto = nil
    transaction do
      update!(estado: "pendiente", confirmado_at: confirmado_at || Time.current) if creado?

      venta = Venta.new(
        cliente: cliente,
        pre_factura: self,
        creado_por: creado_por,
        moneda: moneda,
        estado: "pendiente",
        notas: notas
      )
      pre_factura_items.each do |item|
        venta.venta_items.build(
          paquete: item.paquete,
          concepto: item.concepto,
          peso_cobrar: item.peso_cobrar,
          precio_libra: item.precio_libra,
          subtotal: item.subtotal
        )
      end
      venta.save!

      paquetes_asociados = paquetes.reload.to_a
      paquetes_asociados.each { |p| p.update!(venta_id: venta.id) }

      update!(estado: "facturado", facturado_at: Time.current)
      cliente.increment!(:saldo_pendiente, venta.total)

      # Auto-crea Nota de Debito en estado 'creado' si hay paquetes con solicito_cambio_servicio.
      # El cajero debe revisarla y emitirla manualmente.
      paquetes_cambio = paquetes_asociados.select(&:solicito_cambio_servicio?)
      if paquetes_cambio.any?
        nd = NotaDebito.build_from_paquetes(
          venta,
          paquete_ids: paquetes_cambio.map(&:id),
          motivo: "cambio_servicio",
          user: creado_por
        )
        nd.notas = "Generada automaticamente al facturar PF #{numero} por paquetes con solicitud de cambio de servicio."
        nd.save!
        @nota_debito_auto = nd
      end
    end

    # Fuera de la transaction: encola email idempotente
    if venta && venta.email_pendiente_enviado_at.nil? &&
       cliente.email.present? && cliente.notificar_facturas?
      FacturaMailer.pendiente(venta).deliver_later
      venta.update_column(:email_pendiente_enviado_at, Time.current)
    end

    venta
  end

  def anular!
    return false if facturado? || anulado?

    transaction do
      paquetes.reload.each do |p|
        p.update!(pre_factura_id: nil, estado: "disponible_entrega")
      end
      update!(estado: "anulado")
    end
    true
  end

  # Builds a PreFactura + items for the given paquete_ids (scoped to the
  # cliente). Paquetes must be in bodega Honduras and not already linked to
  # a pre_factura. Precio per pound is calculated from the cliente's
  # categoria_precio (if any) or the tipo_envio default.
  def self.build_from_paquetes(cliente, paquete_ids, user: nil)
    pre_factura = new(
      cliente: cliente,
      creado_por: user,
      fecha_trabajo: Date.current
    )

    paquetes = cliente.paquetes.where(id: paquete_ids).includes(:tipo_envio)
    paquetes.each do |paquete|
      precio = cliente.categoria_precio&.precio_para(paquete.tipo_envio) ||
               paquete.tipo_envio&.precio_libra ||
               BigDecimal("0")
      peso = paquete.peso_cobrar || BigDecimal("0")
      subtotal = (BigDecimal(peso.to_s) * BigDecimal(precio.to_s)).round(2)

      pre_factura.pre_factura_items.build(
        paquete: paquete,
        concepto: "Flete #{paquete.tipo_envio&.nombre || 'Paquete'} - #{paquete.guia}",
        peso_cobrar: peso,
        precio_libra: precio,
        subtotal: subtotal
      )
    end

    pre_factura
  end

  private

  def generate_numero
    next_number = (self.class.where("numero LIKE 'PF-%'")
                    .maximum(Arel.sql("CAST(SUBSTRING(numero FROM 4) AS INTEGER)")) || 0) + 1
    self.numero = "PF-#{next_number.to_s.rjust(6, '0')}"
  end

  def calculate_totals
    sub = pre_factura_items.reject(&:marked_for_destruction?)
                           .sum { |i| i.subtotal.to_d }
    self.subtotal = sub
    self.impuesto = (sub * ISV_RATE).round(2)
    self.total    = (sub + impuesto).round(2)
  end
end
