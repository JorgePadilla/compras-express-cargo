class NotaCreditoItem < ApplicationRecord
  belongs_to :nota_credito, inverse_of: :nota_credito_items
  belongs_to :paquete, optional: true

  validates :concepto, presence: true
  validates :subtotal, presence: true, numericality: { greater_than_or_equal_to: 0 }

  before_validation :calculate_subtotal

  private

  # PR-13.a: ver `VentaItem`. Sin el guard, una nota por un paquete que se
  # cobró al mínimo acredita menos de lo que se cobró.
  def calculate_subtotal
    return if minimo_aplicado?
    return unless paquete_id.present? && peso_cobrar.present? && precio_libra.present?

    self.subtotal = (peso_cobrar.to_d * precio_libra.to_d).round(2, BigDecimal::ROUND_HALF_UP)
  end
end
