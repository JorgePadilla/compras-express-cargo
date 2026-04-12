class VentaItem < ApplicationRecord
  belongs_to :venta, inverse_of: :venta_items
  belongs_to :paquete, optional: true

  validates :concepto, presence: true
  validates :subtotal, numericality: { greater_than_or_equal_to: 0 }

  before_validation :calculate_subtotal_from_peso

  private

  def calculate_subtotal_from_peso
    return unless peso_cobrar.present? && precio_libra.present?
    self.subtotal = (peso_cobrar.to_d * precio_libra.to_d).round(2)
  end
end
