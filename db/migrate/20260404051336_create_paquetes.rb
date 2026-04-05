class CreatePaquetes < ActiveRecord::Migration[8.0]
  def change
    create_table :paquetes do |t|
      t.string :tracking, null: false
      t.string :guia, null: false
      t.references :cliente, null: false, foreign_key: true
      t.bigint :manifiesto_id
      t.references :tipo_envio, foreign_key: true
      t.string :estado, null: false, default: "recibido"
      t.decimal :peso, precision: 10, scale: 2
      t.decimal :volumen, precision: 10, scale: 2
      t.decimal :precio_libra, precision: 10, scale: 2
      t.decimal :monto_total, precision: 10, scale: 2
      t.decimal :alto, precision: 8, scale: 2
      t.decimal :largo, precision: 8, scale: 2
      t.decimal :ancho, precision: 8, scale: 2
      t.decimal :peso_volumetrico, precision: 10, scale: 2
      t.decimal :peso_cobrar, precision: 10, scale: 2
      t.integer :cantidad_productos
      t.integer :cantidad_paquetes
      t.integer :numero_caja
      t.text :descripcion
      t.string :remitente
      t.string :expedido_por
      t.string :proveedor
      t.text :notas_internas
      t.boolean :pre_alerta, default: false
      t.boolean :pre_factura, default: false
      t.boolean :solicito_cambio_servicio, default: false
      t.boolean :retener_miami, default: false
      t.datetime :fecha_recibido_miami
      t.datetime :fecha_enviado
      t.datetime :fecha_llegada_hn
      t.references :user, foreign_key: true

      t.timestamps
    end

    add_index :paquetes, :tracking
    add_index :paquetes, :guia, unique: true
    add_index :paquetes, :estado
  end
end
