# PR-D6.a: catálogo de tarifas de recolecta por zona/distancia.
# Yusef pidió 2026-05-01 una tabla configurable en lugar de la tarifa
# fija $35 USD que se había planteado en PR-D1.c.
#
# El cajero, al asignar una recolecta a un paquete, elige la zona y
# el sistema autocompleta `paquete.recolecta_monto` y la moneda.
# La tarifa se materializa después como línea automática en la
# pre-factura del paquete (PR-D6.b).
class TarifaRecolecta < ApplicationRecord
  has_paper_trail  # PR-D7: audit log de cambios al catálogo
  # Forzar table_name protege contra orden de autoload (mismo patrón
  # usado en Proveedor / MotivoRetencion).
  self.table_name = "tarifas_recolecta"

  MONEDAS = %w[USD LPS].freeze

  validates :zona,   presence: true
  validates :monto,  presence: true,
                     numericality: { greater_than_or_equal_to: 0 }
  validates :moneda, inclusion: { in: MONEDAS }

  normalizes :moneda, with: ->(m) { m.to_s.upcase }

  scope :activas, -> { where(activo: true) }
  scope :ordered, -> { order(:position, :zona) }

  def to_s
    "#{zona} (#{monto} #{moneda})"
  end
end
