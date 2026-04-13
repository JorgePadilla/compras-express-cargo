class CreateCotizaciones < ActiveRecord::Migration[8.0]
  def change
    create_table :cotizaciones do |t|
      t.string  :numero, null: false
      t.references :cliente, null: false, foreign_key: true
      t.string  :estado, null: false, default: "borrador"
      t.decimal :subtotal, precision: 10, scale: 2, default: 0
      t.decimal :impuesto, precision: 10, scale: 2, default: 0
      t.decimal :total, precision: 10, scale: 2, default: 0
      t.string  :moneda, null: false, default: "LPS"
      t.decimal :tasa_cambio_aplicada, precision: 10, scale: 4
      t.text    :notas
      t.text    :terminos
      t.integer :vigencia_dias, default: 30
      t.date    :fecha_vencimiento
      t.references :creado_por, foreign_key: { to_table: :users }
      t.datetime :enviada_at
      t.datetime :aceptada_at
      t.datetime :rechazada_at
      t.datetime :email_enviado_at
      t.references :venta, foreign_key: true
      t.timestamps
    end

    add_index :cotizaciones, :numero, unique: true
    add_index :cotizaciones, :estado
  end
end
