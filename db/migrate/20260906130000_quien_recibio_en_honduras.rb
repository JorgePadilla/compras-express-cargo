# Jorge, 2026-09-06, mirando `/guias-y-aduana`: *"siento que a esta vista como
# que le faltan las iniciales de quien está haciendo la acción"*.
#
# Es la hermana de `expedido_por` (`RP-59`): aquélla sella quién armó el
# manifiesto en Miami; ésta, quién puso la fecha de recibido en Honduras. Se
# llama por la fecha de aduana y no por el estado `recibido`, que es otro
# camino (el escaneo físico de `/recepcion_carga`).
class QuienRecibioEnHonduras < ActiveRecord::Migration[8.0]
  def change
    add_column :manifiestos, :recibido_hn_por, :string
  end
end
