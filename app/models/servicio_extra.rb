# PR-D6.a: catálogo de servicios/productos extra que se cargan en
# la pre-factura. Yusef 2026-05-01:
#   "ya incluye ISV — debe haber un area donde crea los servicios /
#    productos y pone Costos, Precio en venta, Tipo de cobro (USD/LPS)"
#
# Ejemplos típicos: cambio de servicio, peso adicional, manejo
# especial. Los cargos se agregan automáticamente a la pre-factura
# cuando el paquete tiene los flags correspondientes (recolecta o
# cambio_servicio) — la lógica vive en PR-D6.b.
class ServicioExtra < ApplicationRecord
  has_paper_trail  # PR-D7: audit log de cambios al catálogo
  self.table_name = "servicios_extra"

  MONEDAS = %w[USD LPS].freeze

  validates :codigo, presence: true,
                     uniqueness: { case_sensitive: false },
                     format: { with: /\A[A-Z0-9_]+\z/, message: "solo mayúsculas, números o guion bajo" }
  validates :descripcion,  presence: true
  validates :costo,        presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :precio_venta, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :moneda,       inclusion: { in: MONEDAS }

  normalizes :codigo, with: ->(c) { c.to_s.strip.upcase }
  normalizes :moneda, with: ->(m) { m.to_s.upcase }

  scope :activos, -> { where(activo: true) }
  scope :ordered, -> { order(:position, :descripcion) }

  def to_s
    "#{codigo} — #{descripcion}"
  end

  def margen
    precio_venta - costo
  end
end
