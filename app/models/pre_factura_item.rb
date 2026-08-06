class PreFacturaItem < ApplicationRecord
  include Descontable

  # PR-D6.b: origen de la línea para distinguir cargos auto de manuales.
  # `manual` = línea de paquete o agregada por el cajero a mano.
  # `auto_recolecta` = generada desde paquete.recolecta_solicitada.
  # `auto_servicio_extra` = generada desde paquete.solicito_cambio_servicio.
  ORIGENES = %w[manual auto_recolecta auto_servicio_extra].freeze

  belongs_to :pre_factura, inverse_of: :pre_factura_items
  belongs_to :paquete, optional: true
  belongs_to :tarifa_recolecta, optional: true
  belongs_to :servicio_extra, optional: true

  validates :concepto, presence: true
  validates :subtotal, numericality: { greater_than_or_equal_to: 0 }
  validates :origen, inclusion: { in: ORIGENES }

  scope :auto, -> { where("origen LIKE 'auto_%'") }
  scope :manual, -> { where(origen: "manual") }

  before_validation :calculate_subtotal_from_peso

  def auto?
    origen.to_s.start_with?("auto_")
  end

  private

  # PR-10.a: `minimo_aplicado` protege los dos casos donde el subtotal NO sale
  # de peso × precio — el cobro mínimo de servicio y el simbólico de prepagado
  # en Miami. Sin ese guard, este callback los pisaba en silencio.
  def calculate_subtotal_from_peso
    return if minimo_aplicado?
    return unless peso_cobrar.present? && precio_libra.present?

    self.subtotal = (peso_cobrar.to_d * precio_libra.to_d).round(2, BigDecimal::ROUND_HALF_UP)
  end
end
