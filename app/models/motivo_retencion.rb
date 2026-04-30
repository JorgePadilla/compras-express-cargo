# PR-D2: catálogo de motivos por los que un paquete puede ser retenido.
# Yusef pidió multi-select cuando estado=retenido (2026-04-29 6:42pm).
# Casos típicos: paquete dañado, confirmar tipo de envío, mercancía
# prohibida, falta declaración, contenido perecedero.
class MotivoRetencion < ApplicationRecord
  self.table_name = "motivos_retencion"

  has_many :paquete_motivos_retencion,
           class_name: "PaqueteMotivoRetencion",
           dependent: :restrict_with_error
  has_many :paquetes,
           through: :paquete_motivos_retencion,
           source:  :paquete

  validates :nombre, presence: true, uniqueness: { case_sensitive: false }

  scope :activos, -> { where(activo: true) }
  scope :ordered, -> { order(:position, :nombre) }

  def to_s
    nombre
  end
end
