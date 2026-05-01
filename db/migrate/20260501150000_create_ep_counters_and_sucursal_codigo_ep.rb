# PR-D3.b: tracking auto-generado para paquetes ENTREGA PERSONAL.
# Yusef confirmó (2026-04-30 + 2026-05-01) el formato:
#   EP-2026-SMI-AMZ-000001
#       └┬─┘ └┬─┘ └┬─┘ └──┬───┘
#       Año Sucursal Proveedor Correlativo
#   (3 letras) (3 letras) (6 dígitos)
#
# - `codigo_ep` en sucursales: 3 letras separadas del `codigo` general
#   (MIA/SPS/TGU), seeded SMI/SZR/SHU. No tocamos el codigo histórico
#   para no romper find_by ni la UI actual.
# - `ep_counters`: counter atómico por (año, sucursal_id, proveedor_id).
#   Patrón ya usado en RecepcionCounter (PR-A) — lock! FOR UPDATE.
class CreateEpCountersAndSucursalCodigoEp < ActiveRecord::Migration[8.0]
  def change
    add_column :sucursales, :codigo_ep, :string, limit: 3
    add_index  :sucursales, :codigo_ep, unique: true, where: "codigo_ep IS NOT NULL"

    create_table :ep_counters do |t|
      t.integer :anio, null: false
      t.references :sucursal,  null: false, foreign_key: { on_delete: :restrict }
      t.references :proveedor, null: false, foreign_key: { on_delete: :restrict }
      t.integer :last_value, null: false, default: 0
      t.timestamps
    end

    add_index :ep_counters, [ :anio, :sucursal_id, :proveedor_id ],
              unique: true, name: "idx_ep_counter_combo"
  end
end
