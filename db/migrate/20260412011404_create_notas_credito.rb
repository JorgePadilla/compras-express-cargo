class CreateNotasCredito < ActiveRecord::Migration[8.0]
  def change
    create_table :notas_credito do |t|
      t.string     :numero, null: false
      t.references :venta,   null: false, foreign_key: true
      t.references :cliente, null: false, foreign_key: true
      t.string     :estado, null: false, default: "creado"
      t.string     :motivo, null: false
      t.decimal    :subtotal, precision: 10, scale: 2, default: 0
      t.decimal    :impuesto, precision: 10, scale: 2, default: 0
      t.decimal    :total,    precision: 10, scale: 2, default: 0
      t.string     :moneda, default: "LPS", null: false
      t.text       :notas
      t.references :creado_por, foreign_key: { to_table: :users }
      t.datetime   :emitido_at
      t.datetime   :anulado_at

      t.timestamps
    end

    add_index :notas_credito, :numero, unique: true
    add_index :notas_credito, :estado
  end
end
