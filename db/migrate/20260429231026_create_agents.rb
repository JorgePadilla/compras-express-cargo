# PR-5c.5 parte 1: modelo Agent según spec WR (`warehouse_receipt_fields.md`
# §6). Sample del PDF: "CORPORACION KARSAM" código 215, San Pedro Sula HND.
# Es una entidad opcional — solo aplica a algunos WR (sub-agencia local).
class CreateAgents < ActiveRecord::Migration[8.0]
  def change
    create_table :agents do |t|
      t.string :codigo, null: false
      t.string :nombre, null: false
      t.string :destination_city
      t.string :destination_country, default: "Honduras"
      t.boolean :activo, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :agents, :codigo, unique: true
    add_index :agents, :activo
  end
end
