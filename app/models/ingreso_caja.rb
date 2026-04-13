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

  private

  def generate_numero
    next_number = self.class.connection.select_value("SELECT nextval('ingresos_caja_numero_seq')")
    self.numero = "IC-#{next_number.to_s.rjust(6, '0')}"
  end

  def actualizar_total_apertura
    apertura_caja.recalcular_totales!
  end
end
