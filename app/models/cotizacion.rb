class Cotizacion < ApplicationRecord
  self.table_name = "cotizaciones"
  include CurrencyAware

  ISV_RATE = Venta::ISV_RATE

  ESTADOS = %w[borrador enviada aceptada rechazada expirada].freeze

  belongs_to :cliente
  belongs_to :creado_por, class_name: "User", optional: true
  belongs_to :venta, optional: true
  has_many :cotizacion_items, dependent: :destroy, inverse_of: :cotizacion

  accepts_nested_attributes_for :cotizacion_items, allow_destroy: true, reject_if: :all_blank

  validates :numero, presence: true, uniqueness: { case_sensitive: false }
  validates :estado, presence: true, inclusion: { in: ESTADOS }

  before_validation :generate_numero, on: :create, if: -> { numero.blank? }
  before_save :calculate_totals
  before_save :set_fecha_vencimiento

  scope :recientes,    -> { order(created_at: :desc) }
  scope :borradores,   -> { where(estado: "borrador") }
  scope :enviadas,     -> { where(estado: "enviada") }
  scope :aceptadas,    -> { where(estado: "aceptada") }
  scope :by_cliente,   ->(id) { where(cliente_id: id) }
  scope :by_estado,    ->(estado) { where(estado: estado) }
  scope :buscar, ->(term) {
    left_joins(:cliente).where(
      "cotizaciones.numero ILIKE :q OR clientes.codigo ILIKE :q OR clientes.nombre ILIKE :q",
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

  def enviar!
    return false unless borrador?

    update!(estado: "enviada", enviada_at: Time.current)
    true
  end

  def aceptar!
    return false unless enviada?

    update!(estado: "aceptada", aceptada_at: Time.current)
    true
  end

  def rechazar!
    return false unless enviada?

    update!(estado: "rechazada", rechazada_at: Time.current)
    true
  end

  def generar_proforma!(user: nil)
    return nil unless aceptada?
    return venta if venta.present?

    proforma = nil
    transaction do
      proforma = Venta.new(
        cliente: cliente,
        creado_por: user,
        moneda: moneda,
        estado: "proforma",
        notas: "Generada desde cotizacion #{numero}"
      )
      cotizacion_items.each do |item|
        proforma.venta_items.build(
          paquete: item.paquete,
          concepto: item.concepto,
          peso_cobrar: item.peso_cobrar,
          precio_libra: item.precio_libra,
          subtotal: item.subtotal
        )
      end
      proforma.save!
      update!(venta: proforma)
    end
    proforma
  end

  def self.marcar_expiradas!
    enviadas.where("fecha_vencimiento < ?", Date.current).find_each do |ct|
      ct.update!(estado: "expirada")
    end
  end

  private

  def generate_numero
    next_number = (self.class.where("numero LIKE 'CT-%'")
                    .maximum(Arel.sql("CAST(SUBSTRING(numero FROM 4) AS INTEGER)")) || 0) + 1
    self.numero = "CT-#{next_number.to_s.rjust(6, '0')}"
  end

  def calculate_totals
    sub = cotizacion_items.reject(&:marked_for_destruction?)
                          .sum { |i| i.subtotal.to_d }
    self.subtotal = sub
    self.impuesto = (sub * ISV_RATE).round(2)
    self.total    = (sub + impuesto).round(2)
  end

  def set_fecha_vencimiento
    if fecha_vencimiento.blank? && vigencia_dias.present?
      self.fecha_vencimiento = (created_at&.to_date || Date.current) + vigencia_dias.days
    end
  end
end
