class AddFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :nombre, :string, null: false, default: ""
    add_column :users, :rol, :string, null: false, default: "digitador_miami"
    add_column :users, :ubicacion, :string, default: "honduras"
    add_column :users, :activo, :boolean, null: false, default: true

    add_index :users, :rol
    add_index :users, :ubicacion
    add_index :users, :activo
  end
end
