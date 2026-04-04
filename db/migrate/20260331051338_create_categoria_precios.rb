class CreateCategoriaPrecios < ActiveRecord::Migration[8.0]
  def change
    create_table :categoria_precios do |t|
      t.string :nombre, null: false
      t.decimal :precio_libra_aereo, precision: 10, scale: 2
      t.decimal :precio_libra_maritimo, precision: 10, scale: 2
      t.decimal :precio_volumen, precision: 10, scale: 2

      t.timestamps
    end
  end
end
