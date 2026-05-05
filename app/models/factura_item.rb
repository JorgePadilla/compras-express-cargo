class FacturaItem < ApplicationRecord
  belongs_to :factura, inverse_of: :factura_items
  belongs_to :paquete, optional: true
  belongs_to :tarifa_recolecta, optional: true
  belongs_to :servicio_extra,   optional: true

  # Legacy method aliases para código que aún usa `factura_item.venta`.
  # PR-3 los migrará a `.factura`.
  def venta;  factura;  end
  def venta=(v); self.factura = v; end

  ORIGENES = %w[manual auto_recolecta auto_servicio_extra].freeze

  validates :concepto, presence: true
  validates :subtotal, numericality: { greater_than_or_equal_to: 0 }
  validates :origen, inclusion: { in: ORIGENES }

  scope :auto,   -> { where("origen LIKE 'auto_%'") }
  scope :manual, -> { where(origen: "manual") }

  before_validation :calculate_subtotal_from_peso

  def auto?
    origen.to_s.start_with?("auto_")
  end

  private

  def calculate_subtotal_from_peso
    return unless peso_cobrar.present? && precio_libra.present?
    self.subtotal = (peso_cobrar.to_d * precio_libra.to_d).round(2)
  end
end
