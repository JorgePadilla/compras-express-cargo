class VentaItem < ApplicationRecord
  include Descontable

  belongs_to :venta, inverse_of: :venta_items
  belongs_to :paquete, optional: true

  validates :concepto, presence: true
  validates :subtotal, numericality: { greater_than_or_equal_to: 0 }

  before_validation :calculate_subtotal_from_peso

  private

  # PR-13.a: mismo guard que `PreFacturaItem`. Sin él, al facturar se pisaba el
  # mínimo de servicio con `peso × precio` — un CER de 0.5 lb pasaba de los
  # L.173.91 de la pre-factura a L.55.92 en la factura — y el cobro simbólico
  # de prepagado en Miami volvía a $0, porque `precio_libra: 0` cuenta como
  # present.
  def calculate_subtotal_from_peso
    return if minimo_aplicado?
    return unless peso_cobrar.present? && precio_libra.present?

    self.subtotal = (peso_cobrar.to_d * precio_libra.to_d).round(2, BigDecimal::ROUND_HALF_UP)
  end
end
