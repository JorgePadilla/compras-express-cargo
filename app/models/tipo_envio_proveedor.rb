# C21-08 · El tipo de envío del PROVEEDOR — «AEREO EXPRESS», «CKM MARITIMO».
#
# No confundir con `TipoEnvio`, que es **el nuestro** (CER, CKA, CEM, CKM,
# EXPRESS). Son dos cosas distintas que hasta hoy compartían un solo campo: el
# formulario del manifiesto rotulaba «Tipo de Envio» y lo llenaba con
# `TipoEnvio.activos`, cuando el dato que va ahí es el del proveedor. Yusef lo
# dijo con molestia:
#
#   > "Los nombres son malos… dice «tipo de envío de manifiesto»; tengo que
#   >  aprenderme que el tipo de envío del manifiesto es el del proveedor. Aquí
#   >  me pierdo."
#   > "[Me costó] hasta un año, porque nunca me explicó dónde era que yo tenía
#   >  que poner el tipo de envío."
class TipoEnvioProveedor < ApplicationRecord
  has_paper_trail

  validates :nombre, presence: true, uniqueness: { case_sensitive: false }

  scope :activos, -> { where(activo: true) }
  scope :ordered, -> { order(:position, :nombre) }

  def to_s = nombre
end
