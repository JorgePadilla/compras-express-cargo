class CreateLugars < ActiveRecord::Migration[8.0]
  def change
    create_table :lugars do |t|
      t.string :nombre, null: false
      t.string :tipo
      t.text :direccion

      t.timestamps
    end
  end
end
