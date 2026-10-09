# C21-03 · Un tipo de envío **nuestro** que viaja en este manifiesto.
#
# Yusef: *"aquí es tipo de envío nuestro, el interno nuestro… aquí es selección
# múltiple… podés seleccionar todos los cinco tipos de servicio que tengo
# actuales. ¿Por qué seleccionás todo? Porque a veces combinás todo y lo
# mandás"*.
#
# Mismo esqueleto que `PaqueteMotivoRetencion` y `PaqueteMotivoEnvioPolitica`:
# el multi-select que este repo ya resolvió dos veces.
class ManifiestoTipoEnvio < ApplicationRecord
  belongs_to :manifiesto
  belongs_to :tipo_envio

  validates :tipo_envio_id, uniqueness: { scope: :manifiesto_id }
end
