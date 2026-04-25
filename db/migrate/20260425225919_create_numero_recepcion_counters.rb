class CreateNumeroRecepcionCounters < ActiveRecord::Migration[8.0]
  def change
    create_table :numero_recepcion_counters do |t|
      t.references :sucursal, null: false, foreign_key: { to_table: :sucursales }
      t.integer :anio, null: false
      t.integer :ultimo_numero, null: false, default: 0
      t.timestamps
    end

    add_index :numero_recepcion_counters, %i[sucursal_id anio], unique: true,
              name: "idx_recepcion_counters_sucursal_anio"
  end
end
