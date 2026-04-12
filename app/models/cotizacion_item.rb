class CotizacionItem < ApplicationRecord
  belongs_to :cotizacion, inverse_of: :cotizacion_items
  belongs_to :paquete, optional: true

  validates :concepto, presence: true
  validates :subtotal, numericality: { greater_than_or_equal_to: 0 }

  before_validation :calculate_subtotal

  private

  def calculate_subtotal
    if peso_cobrar.present? && precio_libra.present?
      self.subtotal = (peso_cobrar.to_d * precio_libra.to_d).round(2)
    elsif cantidad.present? && precio_unitario.present?
      self.subtotal = (cantidad.to_d * precio_unitario.to_d).round(2)
    end
  end
end
