class NotaDebito < ApplicationRecord
  self.table_name = "notas_debito"
  include CurrencyAware

  ISV_RATE = Venta::ISV_RATE

  ESTADOS = %w[creado emitido anulado].freeze
  MOTIVOS = %w[cambio_servicio peso_adicional ajuste_manual otro].freeze

  belongs_to :venta
  belongs_to :cliente
  belongs_to :creado_por, class_name: "User", optional: true
  has_many :nota_debito_items, dependent: :destroy, inverse_of: :nota_debito
  has_many :paquetes, -> { distinct }, through: :nota_debito_items

  accepts_nested_attributes_for :nota_debito_items, allow_destroy: true, reject_if: :all_blank

  validates :numero, presence: true, uniqueness: { case_sensitive: false }
  validates :estado, presence: true, inclusion: { in: ESTADOS }
  validates :motivo, presence: true, inclusion: { in: MOTIVOS }

  before_validation :generate_numero, on: :create, if: -> { numero.blank? }
  before_save :calculate_totals

  scope :recientes, -> { order(created_at: :desc) }
  scope :creadas,   -> { where(estado: "creado") }
  scope :emitidas,  -> { where(estado: "emitido") }
  scope :anuladas,  -> { where(estado: "anulado") }
  scope :by_venta,   ->(id) { where(venta_id: id) }
  scope :by_cliente, ->(id) { where(cliente_id: id) }
  scope :by_estado,  ->(estado) { where(estado: estado) }
  scope :buscar, ->(term) {
    left_joins(:cliente).where(
      "notas_debito.numero ILIKE :q OR clientes.codigo ILIKE :q OR clientes.nombre ILIKE :q",
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

  def emitir!
    return false unless creado?

    transaction do
      update!(estado: "emitido", emitido_at: Time.current)
      cliente.increment!(:saldo_pendiente, total)
    end
    true
  end

  def anular!
    return false unless emitido?

    transaction do
      update!(estado: "anulado", anulado_at: Time.current)
      nuevo = cliente.saldo_pendiente.to_d - total.to_d
      cliente.update!(saldo_pendiente: [nuevo, BigDecimal("0")].max)
    end
    true
  end

  def self.build_from_paquetes(venta, paquete_ids:, motivo: "ajuste_manual", user: nil)
    cliente = venta.cliente
    nd = new(
      venta: venta,
      cliente: cliente,
      motivo: motivo,
      estado: "creado",
      moneda: venta.moneda,
      creado_por: user
    )

    paquetes = cliente.paquetes.where(id: paquete_ids).includes(:tipo_envio)
    paquetes.each do |paquete|
      precio = cliente.categoria_precio&.precio_para(paquete.tipo_envio) ||
               paquete.tipo_envio&.precio_libra ||
               BigDecimal("0")
      peso = paquete.peso_cobrar || BigDecimal("0")
      subtotal = (BigDecimal(peso.to_s) * BigDecimal(precio.to_s)).round(2)

      nd.nota_debito_items.build(
        paquete: paquete,
        concepto: "Ajuste #{paquete.tipo_envio&.nombre || 'Paquete'} - #{paquete.guia}",
        peso_cobrar: peso,
        precio_libra: precio,
        subtotal: subtotal
      )
    end

    nd
  end

  private

  def generate_numero
    next_number = (self.class.where("numero LIKE 'ND-%'")
                    .maximum(Arel.sql("CAST(SUBSTRING(numero FROM 4) AS INTEGER)")) || 0) + 1
    self.numero = "ND-#{next_number.to_s.rjust(6, '0')}"
  end

  def calculate_totals
    sub = nota_debito_items.reject(&:marked_for_destruction?)
                           .sum { |i| i.subtotal.to_d }
    self.subtotal = sub
    self.impuesto = (sub * ISV_RATE).round(2)
    self.total    = (sub + impuesto).round(2)
  end
end
