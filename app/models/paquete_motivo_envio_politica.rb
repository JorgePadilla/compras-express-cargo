# C18-06: join entre Paquete y MotivoEnvioPolitica. Un paquete enviado por
# política puede llevar varios motivos («sin pre-alerta» y «etiqueta
# incompleta» a la vez).
class PaqueteMotivoEnvioPolitica < ApplicationRecord
  self.table_name = "paquete_motivos_envio_politica"

  belongs_to :paquete
  belongs_to :motivo_envio_politica

  validates :paquete_id, uniqueness: { scope: :motivo_envio_politica_id }
end
