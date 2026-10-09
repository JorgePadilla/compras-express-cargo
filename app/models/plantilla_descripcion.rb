# C19-04: catálogo de descripciones frecuentes del contenido. Yusef: "hay dos
# cosas: sellado y compra chino, son más comunes" — muchos paquetes no se
# abren y en el sistema viejo escriben "sellado" a mano mil veces. Gemelo de
# PlantillaNotaCliente, con el mismo picker; se inserta en
# `paquete.descripcion` desde /etiquetar, /entrega_personal y /paquetes.
class PlantillaDescripcion < ApplicationRecord
  has_paper_trail
  self.table_name = "plantillas_descripcion"

  validates :titulo, presence: true
  validates :texto,  presence: true

  scope :activas, -> { where(activo: true) }
  scope :ordered, -> { order(:position, :titulo) }

  def to_s
    titulo
  end
end
