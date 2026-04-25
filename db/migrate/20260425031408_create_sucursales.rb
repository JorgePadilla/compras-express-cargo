class CreateSucursales < ActiveRecord::Migration[8.0]
  def change
    create_table :sucursales do |t|
      t.string :codigo, null: false
      t.string :nombre, null: false
      t.string :pais
      t.string :ubicacion
      t.string :codigo_recepcion_prefix, null: false
      t.boolean :activo, null: false, default: true

      t.timestamps
    end

    add_index :sucursales, :codigo, unique: true
    add_index :sucursales, :codigo_recepcion_prefix, unique: true
  end
end
