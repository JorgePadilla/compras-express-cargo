class CreateCarriers < ActiveRecord::Migration[8.0]
  def change
    create_table :carriers do |t|
      t.string :nombre, null: false
      t.string :tipo
      t.boolean :activo, default: true

      t.timestamps
    end
  end
end
