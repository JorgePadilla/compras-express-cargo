class CreateManifiestos < ActiveRecord::Migration[8.0]
  def change
    create_table :manifiestos do |t|
      t.string :numero, null: false
      t.string :numero_caja
      t.string :numero_guia
      t.references :empresa_manifiesto, foreign_key: true
      t.string :estado, null: false, default: "creado"
      t.string :tipo_envio
      t.string :expedido_por
      t.integer :cantidad_paquetes, default: 0
      t.decimal :volumen_total, precision: 10, scale: 2
      t.decimal :peso_total, precision: 10, scale: 2
      t.datetime :fecha_enviado
      t.datetime :fecha_aduana
      t.references :user, foreign_key: true
      t.boolean :activo, default: true

      t.timestamps
    end

    add_index :manifiestos, :numero, unique: true
    add_index :manifiestos, :estado

    add_foreign_key :paquetes, :manifiestos
    add_index :paquetes, :manifiesto_id
  end
end
