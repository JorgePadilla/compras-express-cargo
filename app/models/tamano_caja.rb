# C21-08 / C21-04 · Los tamaños de caja con los que empacan en Miami.
#
# La pantalla vieja ofrece diez: Especificar, EH, D, 22 Cubo, 18 Cubo, D G,
# EH G, E, Mini D y Mini D Doble. El modelo existía desde `PR-D7` con la forma
# correcta —nombre y las tres medidas— pero **sin una sola fila y sin pantalla**.
#
# Las medidas son un **punto de partida, no un valor fijo**:
#
#   > "Ellos vienen y marcan EH y le modifican una medida, porque la cortan…
#   >  le decimos «EH cortada»."
#
# Y la medida real importa porque el proveedor cobra por ese reporte:
#
#   > "Tenés que reportarlo a tu proveedor… yo agarro el reporte y ellos me
#   >  cobran [según] el reporte."
class TamanoCaja < ApplicationRecord
  has_paper_trail

  validates :nombre, presence: true, uniqueness: { case_sensitive: false }
  validates :alto, :largo, :ancho,
            numericality: { greater_than: 0 }, allow_nil: true

  scope :activos, -> { where(activo: true) }
  scope :ordered, -> { order(:position, :nombre) }

  # Las tres medidas puestas: el que las tiene pre-llena el formulario de la
  # caja y manda el cursor al peso. «Especificar» no las tiene a propósito.
  def medidas_completas?
    alto.present? && largo.present? && ancho.present?
  end

  def to_s = nombre
end
