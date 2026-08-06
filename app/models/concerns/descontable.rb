# PR-13.b: el descuento de una línea de cobro.
#
# `descuento_monto` es el número autoritativo — es el que suma y el que se
# imprime. `descuento_porcentaje` solo se guarda si así se capturó, para que la
# factura pueda decir "Descuento (10%)" en vez de un monto suelto.
#
# Escribir el porcentaje calcula el monto sobre el subtotal de la línea. De ahí
# en adelante manda el monto: si después cambia el subtotal, el descuento **no**
# se recalcula solo. Es a propósito — un descuento que se mueve solo después de
# que un supervisor lo autorizó deja de ser lo que se autorizó.
module Descontable
  extend ActiveSupport::Concern

  included do
    validates :descuento_monto, numericality: { greater_than_or_equal_to: 0 }
    validates :descuento_porcentaje,
              numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
              allow_nil: true
    validate :descuento_no_supera_el_subtotal
  end

  # Lo que realmente se cobra por esta línea.
  def total_linea
    (subtotal.to_d - descuento_monto.to_d).round(2, BigDecimal::ROUND_HALF_UP)
  end

  def descuento?
    descuento_monto.to_d.positive?
  end

  # Para la vista: "10%" o "L. 200.00".
  def descuento_label
    return nil unless descuento?
    return "#{descuento_porcentaje.to_d.to_i}%" if descuento_porcentaje.present?

    format("%.2f", descuento_monto)
  end

  # El setter que usa el modal de autorización cuando se captura como
  # porcentaje. El monto queda fijado acá y el % queda como constancia.
  def aplicar_descuento_porcentaje(porcentaje)
    pct = BigDecimal(porcentaje.to_s)
    self.descuento_porcentaje = pct
    self.descuento_monto = (subtotal.to_d * pct / 100).round(2, BigDecimal::ROUND_HALF_UP)
  end

  def aplicar_descuento_monto(monto)
    self.descuento_porcentaje = nil
    self.descuento_monto = BigDecimal(monto.to_s)
  end

  private

  # Un descuento mayor que la línea daría un total negativo, que en una factura
  # no significa nada. Si hay que devolverle plata al cliente, eso es una nota
  # de crédito.
  def descuento_no_supera_el_subtotal
    return if descuento_monto.blank? || subtotal.blank?
    return if descuento_monto.to_d <= subtotal.to_d

    errors.add(:descuento_monto, "no puede ser mayor que el subtotal de la linea")
  end
end
