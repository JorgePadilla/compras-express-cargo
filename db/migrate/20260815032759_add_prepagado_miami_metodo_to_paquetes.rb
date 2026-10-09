# Con qué se pagó, cuando el paquete se pagó en Miami.
#
# Yusef pidió el marcado de "pagado en Miami" y quedó a medias: se guarda que
# se pagó, quién, cuándo y en qué sucursal — pero no con qué. Cuando el paquete
# llega a Honduras, el cajero arma el cobro simbólico sin saber si entró
# efectivo, Zelle o tarjeta.
#
# Nula por defecto: solo los paquetes prepagados en Miami la llevan, y el
# modelo valida las dos direcciones.
class AddPrepagadoMiamiMetodoToPaquetes < ActiveRecord::Migration[8.0]
  def change
    add_column :paquetes, :prepagado_miami_metodo, :string
  end
end
