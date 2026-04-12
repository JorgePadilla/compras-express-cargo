class CreatePreFacturas < ActiveRecord::Migration[8.0]
  def change
    create_table :pre_facturas do |t|
      t.string :numero, null: false
      t.references :cliente, null: false, foreign_key: true
      t.string :estado, null: false, default: "creado"
      t.decimal :subtotal, precision: 10, scale: 2, default: 0
      t.decimal :impuesto, precision: 10, scale: 2, default: 0
      t.decimal :total, precision: 10, scale: 2, default: 0
      t.string :moneda, null: false, default: "LPS"
      t.date :fecha_trabajo
      t.text :notas
      t.references :creado_por, foreign_key: { to_table: :users }
      t.datetime :confirmado_at
      t.datetime :facturado_at

      t.timestamps
    end

    add_index :pre_facturas, :numero, unique: true
    add_index :pre_facturas, :estado
  end
end
