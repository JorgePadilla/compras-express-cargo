class IngresoCaja < ApplicationRecord
  self.table_name = "ingresos_caja"

  METODOS_PAGO = %w[efectivo tarjeta transferencia].freeze

  belongs_to :apertura_caja, class_name: "AperturaCaja", foreign_key: :apertura_caja_id
  belongs_to :registrado_por, class_name: "User", optional: true

  validates :numero, presence: true, uniqueness: { case_sensitive: false }
  validates :monto, numericality: { greater_than: 0 }
  validates :concepto, presence: true
  validates :metodo_pago, presence: true, inclusion: { in: METODOS_PAGO }

  before_validation :generate_numero, on: :create, if: -> { numero.blank? }
  after_create :actualizar_total_apertura

  scope :recientes, -> { order(created_at: :desc) }

  def save(**args, &block)
    super
  rescue ActiveRecord::RecordNotUnique => e
    raise unless new_record? && e.message.include?("numero") && (@_numero_retries ||= 0) < 3
    @_numero_retries += 1
    self.numero = nil
    generate_numero
    retry
  end

  private

  def generate_numero
    next_number = (self.class.where("numero LIKE 'IC-%'")
                    .maximum(Arel.sql("CAST(SUBSTRING(numero FROM 4) AS INTEGER)")) || 0) + 1
    self.numero = "IC-#{next_number.to_s.rjust(6, '0')}"
  end

  def actualizar_total_apertura
    apertura_caja.recalcular_totales!
  end
end
