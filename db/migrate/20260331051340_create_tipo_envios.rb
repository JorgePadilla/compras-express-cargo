class CreateTipoEnvios < ActiveRecord::Migration[8.0]
  def change
    create_table :tipo_envios do |t|
      t.string :nombre, null: false
      t.string :codigo
      t.boolean :activo, default: true

      t.timestamps
    end
  end
end
