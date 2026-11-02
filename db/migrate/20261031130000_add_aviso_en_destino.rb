# C34-08 · C33-04 · La pre-factura de un cliente que no retira donde está la
# carga no le avisa al F9: queda **esperando que llegue** (`espera_llegada_at`),
# y avisa la recepción del manifiesto interno en destino, a la hora que elige
# quien recibe (`manifiestos.aviso_llegada_at`). Yusef: *"no va a notificar si
# es de una sucursal y no ha llegado a la sucursal"* · *"recibir carga interna,
# manifiesto, ¿a qué hora es lo notificado? Tal hora"*.
class AddAvisoEnDestino < ActiveRecord::Migration[8.0]
  def change
    add_column :pre_facturas, :espera_llegada_at, :datetime
    add_column :manifiestos, :aviso_llegada_at, :datetime
  end
end
