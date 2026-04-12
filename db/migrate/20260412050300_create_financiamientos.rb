class CreateFinanciamientos < ActiveRecord::Migration[8.0]
  def change
    create_table :financiamientos do |t|
      t.string  :numero, null: false
      t.references :venta, null: false, foreign_key: true
      t.references :cliente, null: false, foreign_key: true
      t.string  :estado, null: false, default: "activo"
      t.integer :numero_cuotas, null: false
      t.decimal :monto_total, precision: 10, scale: 2, null: false
      t.decimal :monto_cuota, precision: 10, scale: 2, null: false
      t.string  :moneda, null: false, default: "LPS"
      t.decimal :tasa_cambio_aplicada, precision: 10, scale: 4
      t.string  :frecuencia, null: false, default: "mensual"
      t.date    :fecha_inicio, null: false
      t.text    :notas
      t.references :creado_por, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :financiamientos, :numero, unique: true
    add_index :financiamientos, :estado
  end
end
