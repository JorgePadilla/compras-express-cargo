# PR-5c.5 parte 1: modelo Supplier (Proveedor) según spec WR.
# El proveedor de la mercancía (ej. Amazon LLC, eBay). Tiene código manual
# asignado por el admin al crear (Yusef 2026-04-29), no autogenerado.
class CreateSuppliers < ActiveRecord::Migration[8.0]
  def change
    create_table :suppliers do |t|
      t.string :codigo, null: false
      t.string :nombre, null: false
      t.string :tipo, null: false, default: "comercio"  # comercio | entrega_personal | otros
      t.string :street_address
      t.string :city
      t.string :state
      t.string :postal_code
      t.string :country, default: "USA"
      t.boolean :activo, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :suppliers, :codigo, unique: true
    add_index :suppliers, :tipo
    add_index :suppliers, :activo
  end
end
