class CreateConfiguracions < ActiveRecord::Migration[8.0]
  def change
    create_table :configuracions do |t|
      t.string :clave, null: false
      t.text :valor
      t.string :tipo
      t.string :categoria

      t.timestamps
    end

    add_index :configuracions, :clave, unique: true
  end
end
