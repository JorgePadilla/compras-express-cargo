# PR-D2: catálogo de plantillas de notas al cliente. Compartidas entre
# Etiquetar / Pre-Factura / Caja / SAC para evitar reescribir info
# recurrente.
class PlantillaNotaCliente < ApplicationRecord
  self.table_name = "plantillas_notas_cliente"

  validates :titulo, presence: true
  validates :texto,  presence: true

  scope :activas, -> { where(activo: true) }
  scope :ordered, -> { order(:position, :titulo) }

  def to_s
    titulo
  end
end
