# C31-09 · PR-C31.7 · Un manifiesto oficial va a **varias** sucursales.
#
# Yusef, 2026-10-12: *"estamos terminando de cuadrar una caja, y la cortaron
# para que cupiera… y ahí podrías mandar mixto, o podés marcar acá arriba que
# vas a mandar a varias sucursales"* · *"si tenemos dos sucursales, Tegus y La
# Ceiba, muy probablemente las empaquemos juntas, porque al final acá las
# vamos a separar"*.
#
# La tabla de unión, como `manifiesto_tipo_envios` (C21-03). Solo para el
# **oficial**: el interno sigue con su única `sucursal_entrega_id`, que es a
# dónde va el camión.
#
# La de cada oficial que ya tenía se copia como su primera fila, en SQL y no
# con el modelo. `sucursal_entrega_id` no se borra en el oficial: así la
# migración vuelve atrás sin perder nada.
class ManifiestoSucursalesEntrega < ActiveRecord::Migration[8.0]
  def up
    create_table :manifiesto_sucursales_entrega do |t|
      t.references :manifiesto, null: false, foreign_key: true, index: false
      t.references :sucursal, null: false, foreign_key: { to_table: :sucursales }
      t.timestamps
    end
    add_index :manifiesto_sucursales_entrega, %i[manifiesto_id sucursal_id], unique: true,
              name: "index_manifiesto_sucursales_entrega_unica"

    execute <<~SQL
      INSERT INTO manifiesto_sucursales_entrega (manifiesto_id, sucursal_id, created_at, updated_at)
      SELECT id, sucursal_entrega_id, NOW(), NOW()
      FROM manifiestos
      WHERE tipo = 'oficial' AND sucursal_entrega_id IS NOT NULL
    SQL
  end

  def down
    drop_table :manifiesto_sucursales_entrega
  end
end
