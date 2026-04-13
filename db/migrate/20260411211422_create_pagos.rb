class CreatePagos < ActiveRecord::Migration[8.0]
  def change
    create_table :pagos do |t|
      t.references :venta, null: false, foreign_key: { to_table: :ventas }
      t.references :cliente, null: false, foreign_key: true
      t.decimal :monto, precision: 10, scale: 2, null: false
      t.string :metodo_pago, null: false
      t.string :moneda, null: false, default: "LPS"
      t.string :estado, null: false, default: "completado"
      t.datetime :pagado_at
      t.text :notas
      t.references :registrado_por, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :pagos, :estado
  end
end
