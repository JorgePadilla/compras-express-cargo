class NotaDebitoItem < ApplicationRecord
  belongs_to :nota_debito, inverse_of: :nota_debito_items
  belongs_to :paquete, optional: true

  validates :concepto, presence: true
  validates :subtotal, presence: true, numericality: { greater_than_or_equal_to: 0 }

  before_validation :calculate_subtotal

  private

  # PR-13.a: ver `VentaItem`. Sin el guard, una nota por un paquete que se
  # cobró al mínimo ajusta sobre un monto que nunca se cobró.
  def calculate_subtotal
    return if minimo_aplicado?
    return unless paquete_id.present? && peso_cobrar.present? && precio_libra.present?

    self.subtotal = (peso_cobrar.to_d * precio_libra.to_d).round(2, BigDecimal::ROUND_HALF_UP)
  end
end
