class CreateCotizacionItems < ActiveRecord::Migration[8.0]
  def change
    create_table :cotizacion_items do |t|
      t.references :cotizacion, null: false, foreign_key: { to_table: :cotizaciones }
      t.references :paquete, foreign_key: true
      t.string  :concepto, null: false
      t.decimal :cantidad, precision: 10, scale: 2, default: 1
      t.decimal :precio_unitario, precision: 10, scale: 2, default: 0
      t.decimal :peso_cobrar, precision: 10, scale: 2
      t.decimal :precio_libra, precision: 10, scale: 2
      t.decimal :subtotal, precision: 10, scale: 2, null: false, default: 0
      t.timestamps
    end
  end
end
