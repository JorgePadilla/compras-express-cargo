class CreatePreAlertaPaquetes < ActiveRecord::Migration[8.0]
  def change
    create_table :pre_alerta_paquetes do |t|
      t.references :pre_alerta, null: false, foreign_key: { to_table: :pre_alertas }
      t.references :paquete, null: true, foreign_key: true
      t.string :tracking, null: false
      t.text :descripcion
      t.boolean :retener_miami, default: false
      t.date :fecha

      t.timestamps
    end

    add_index :pre_alerta_paquetes, :tracking
    add_index :pre_alerta_paquetes, [:pre_alerta_id, :tracking], unique: true
  end
end
