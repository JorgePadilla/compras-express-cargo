class FinanciamientoCuota < ApplicationRecord
  self.table_name = "financiamiento_cuotas"

  ESTADOS = %w[pendiente pagada vencida].freeze

  belongs_to :financiamiento
  belongs_to :pago, optional: true

  validates :numero_cuota, numericality: { greater_than: 0 }
  validates :monto, numericality: { greater_than: 0 }
  validates :estado, presence: true, inclusion: { in: ESTADOS }
  validates :fecha_vencimiento, presence: true

  scope :pendientes, -> { where(estado: "pendiente") }
  scope :vencidas,   -> { where(estado: "vencida") }
  scope :pagadas,    -> { where(estado: "pagada") }
  scope :por_pagar,  -> { where(estado: %w[pendiente vencida]).order(:numero_cuota) }

  ESTADOS.each do |estado|
    define_method("#{estado}?") { self.estado == estado }
  end

  def pagar!(pago:)
    return false if pagada?

    transaction do
      update!(estado: "pagada", pagada_at: Time.current, pago: pago)
      financiamiento.verificar_completado!
    end
    true
  end
end
