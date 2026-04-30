# PR-D1.c: cada sucursal puede tener sub-localidades (bodegas internas o
# áreas terceras) para identificar con más precisión dónde está un
# paquete físicamente. Yusef confirmó (2026-04-29):
#   sucursal Zerón → ZR01 (bodega central), ZR02 (bodega CEM), …
#   sucursal Humuya → HM01, …
# Hay cargas que se ponen en áreas terceras dentro/cerca de la sucursal.
class CreateSubLocalidades < ActiveRecord::Migration[8.0]
  def change
    create_table :sub_localidades do |t|
      t.references :sucursal, null: false, foreign_key: { to_table: :sucursales }
      t.string :codigo, null: false       # ZR01, ZR02, HM01, …
      t.string :nombre, null: false       # "Zerón bodega central", …
      t.boolean :activo, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :sub_localidades, [ :sucursal_id, :codigo ], unique: true,
              name: "idx_sub_localidades_sucursal_codigo"
    add_index :sub_localidades, :activo
  end
end
