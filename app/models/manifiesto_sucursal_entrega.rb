# C31-09 · PR-C31.7 · Una sucursal a la que va el manifiesto **oficial**.
#
# Yusef: *"podés marcar acá arriba que vas a mandar a varias sucursales"*.
# Mismo esqueleto que `ManifiestoTipoEnvio` (C21-03). El interno no la usa:
# va a una sola, su `sucursal_entrega_id`, que es a dónde va el camión.
class ManifiestoSucursalEntrega < ApplicationRecord
  self.table_name = "manifiesto_sucursales_entrega"

  belongs_to :manifiesto
  belongs_to :sucursal

  validates :sucursal_id, uniqueness: { scope: :manifiesto_id }
end
