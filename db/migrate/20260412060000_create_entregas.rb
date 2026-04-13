class CreateEntregas < ActiveRecord::Migration[8.0]
  def change
    create_table :entregas do |t|
      t.string :numero, null: false
      t.references :cliente, null: false, foreign_key: true
      t.string :tipo_entrega, null: false, default: "retiro_oficina"
      t.string :estado, null: false, default: "pendiente"
      t.string :receptor_nombre, null: false
      t.string :receptor_identidad, null: false
      t.text :direccion_entrega
      t.references :repartidor, foreign_key: { to_table: :users }
      t.references :creado_por, foreign_key: { to_table: :users }
      t.text :notas
      t.datetime :despachado_at
      t.datetime :entregado_at

      t.timestamps
    end

    add_index :entregas, :numero, unique: true
    add_index :entregas, :estado
    add_index :entregas, :tipo_entrega
  end
end
