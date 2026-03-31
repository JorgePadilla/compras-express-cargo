class CreateTamanoCajas < ActiveRecord::Migration[8.0]
  def change
    create_table :tamano_cajas do |t|
      t.string :nombre, null: false
      t.decimal :largo, precision: 8, scale: 2
      t.decimal :ancho, precision: 8, scale: 2
      t.decimal :alto, precision: 8, scale: 2

      t.timestamps
    end
  end
end
