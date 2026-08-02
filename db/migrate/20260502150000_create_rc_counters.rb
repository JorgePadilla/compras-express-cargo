# PR-D4.d: counter atómico para tracking auto de RECOLECTA.
# Yusef (spec consolidada 2026-05-02):
#
#   "EP=entrega personal y para recoleta seria RC= RECOLECTA
#    (es cuando mandamos un motorista nosotros a recolectar
#    o comprar algo). Si el sistema lo genera automáticamente:
#    RC-2026-SM-AMZ-000001"
#
# Mismo formato y schema que EpCounter pero scope independiente —
# un paquete EP-AMZ-000001 y otro RC-AMZ-000001 conviven sin chocar.
class CreateRcCounters < ActiveRecord::Migration[8.0]
  def change
    create_table :rc_counters do |t|
      t.integer :anio, null: false
      t.references :sucursal,  null: false, foreign_key: { on_delete: :restrict }
      t.references :proveedor, null: false, foreign_key: { on_delete: :restrict }
      t.integer :last_value, null: false, default: 0
      t.timestamps
    end

    add_index :rc_counters, [ :anio, :sucursal_id, :proveedor_id ],
              unique: true, name: "idx_rc_counter_combo"
  end
end
