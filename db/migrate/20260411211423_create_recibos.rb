class CreateRecibos < ActiveRecord::Migration[8.0]
  def change
    create_table :recibos do |t|
      t.string :numero, null: false
      t.references :venta, null: false, foreign_key: { to_table: :ventas }
      t.references :pago, null: false, foreign_key: true
      t.references :cliente, null: false, foreign_key: true
      t.decimal :monto, precision: 10, scale: 2, null: false
      t.string :forma_pago
      t.string :moneda, null: false, default: "LPS"

      t.timestamps
    end

    add_index :recibos, :numero, unique: true
  end
end
