class CreateConsignatarios < ActiveRecord::Migration[8.0]
  def change
    create_table :consignatarios do |t|
      t.string :nombre, null: false
      t.string :identidad
      t.text :direccion

      t.timestamps
    end
  end
end
