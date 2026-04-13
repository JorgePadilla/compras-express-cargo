class CreateVentas < ActiveRecord::Migration[8.0]
  def change
    create_table :ventas do |t|
      t.string :numero, null: false
      t.references :cliente, null: false, foreign_key: true
      t.references :pre_factura, foreign_key: true
      t.string :estado, null: false, default: "pendiente"
      t.decimal :subtotal, precision: 10, scale: 2, default: 0
      t.decimal :impuesto, precision: 10, scale: 2, default: 0
      t.decimal :total, precision: 10, scale: 2, default: 0
      t.decimal :saldo_pendiente, precision: 10, scale: 2, default: 0
      t.string :moneda, null: false, default: "LPS"
      t.text :notas
      t.references :creado_por, foreign_key: { to_table: :users }
      t.datetime :pagada_at

      t.timestamps
    end

    add_index :ventas, :numero, unique: true
    add_index :ventas, :estado
  end
end
