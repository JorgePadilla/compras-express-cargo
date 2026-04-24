class CreateTareas < ActiveRecord::Migration[8.0]
  def change
    create_table :tareas do |t|
      t.references :paquete, null: false, foreign_key: true
      t.references :asignado_a, foreign_key: { to_table: :users }
      t.references :completado_por, foreign_key: { to_table: :users }

      t.string :titulo, null: false
      t.text :descripcion
      t.string :estado, null: false, default: "pendiente"
      t.datetime :completada_en
      t.text :notas

      t.timestamps
    end

    add_index :tareas, :estado
  end
end
