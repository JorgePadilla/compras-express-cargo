class CreateNotaCreditoItems < ActiveRecord::Migration[8.0]
  def change
    create_table :nota_credito_items do |t|
      t.references :nota_credito, null: false, foreign_key: true
      t.references :paquete,      foreign_key: true
      t.string     :concepto, null: false
      t.decimal    :peso_cobrar,  precision: 10, scale: 2
      t.decimal    :precio_libra, precision: 10, scale: 2
      t.decimal    :subtotal,     precision: 10, scale: 2, null: false, default: 0

      t.timestamps
    end
  end
end
