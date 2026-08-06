class NotaCredito < ApplicationRecord
  has_paper_trail  # PR-D7: audit log
  self.table_name = "notas_credito"
  include CurrencyAware
  include IsvAware
  include LineasDeFlete

  ESTADOS = %w[creado emitido anulado].freeze
  MOTIVOS = %w[devolucion descuento error_facturacion otro].freeze

  belongs_to :venta
  belongs_to :cliente
  belongs_to :creado_por, class_name: "User", optional: true
  # PR-13.e: la autorizacion con la que un supervisor la emitio.
  has_many :autorizaciones, as: :documento, dependent: :destroy
  has_many :nota_credito_items, dependent: :destroy, inverse_of: :nota_credito
  has_many :paquetes, -> { distinct }, through: :nota_credito_items

  accepts_nested_attributes_for :nota_credito_items, allow_destroy: true, reject_if: :all_blank

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
      "notas_credito.numero ILIKE :q OR clientes.codigo ILIKE :q OR clientes.nombre ILIKE :q",
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
      nuevo = cliente.saldo_pendiente.to_d - total.to_d
      cliente.update!(saldo_pendiente: [nuevo, BigDecimal("0")].max)
    end
    true
  end

  def anular!
    return false unless emitido?

    transaction do
      update!(estado: "anulado", anulado_at: Time.current)
      cliente.increment!(:saldo_pendiente, total)
    end
    true
  end

  def self.build_from_paquetes(venta, paquete_ids:, motivo: "descuento", user: nil)
    cliente = venta.cliente
    nc = new(
      venta: venta,
      cliente: cliente,
      motivo: motivo,
      estado: "creado",
      moneda: venta.moneda,
      creado_por: user
    )

    lineas_de_flete(cliente: cliente, paquete_ids: paquete_ids,
                    moneda: nc.moneda, concepto_prefijo: "Credito")
      .each { |attrs| nc.nota_credito_items.build(attrs) }

    nc
  end

  private

  def generate_numero
    next_number = (self.class.where("numero LIKE 'NC-%'")
                    .maximum(Arel.sql("CAST(SUBSTRING(numero FROM 4) AS INTEGER)")) || 0) + 1
    self.numero = "NC-#{next_number.to_s.rjust(6, '0')}"
  end

  def calculate_totals
    sub = nota_credito_items.reject(&:marked_for_destruction?)
                            .sum { |i| i.subtotal.to_d }
    self.subtotal = sub
    self.impuesto = (sub * isv_rate).round(2, BigDecimal::ROUND_HALF_UP)
    self.total    = (sub + impuesto).round(2)
  end
end
