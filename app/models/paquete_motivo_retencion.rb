# PR-D2: join entre Paquete y MotivoRetencion. Un paquete retenido
# puede tener múltiples motivos seleccionados.
class PaqueteMotivoRetencion < ApplicationRecord
  self.table_name = "paquete_motivos_retencion"

  belongs_to :paquete
  belongs_to :motivo_retencion

  validates :paquete_id, uniqueness: { scope: :motivo_retencion_id }
end
