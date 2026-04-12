class CreateAperturasCaja < ActiveRecord::Migration[8.0]
  def change
    create_table :aperturas_caja do |t|
      t.string :numero, null: false
      t.date :fecha, null: false
      t.string :estado, null: false, default: "abierta"
      t.decimal :monto_apertura, precision: 10, scale: 2, null: false, default: 0
      t.decimal :monto_cierre, precision: 10, scale: 2
      t.decimal :total_pagos, precision: 10, scale: 2, default: 0
      t.decimal :total_ingresos, precision: 10, scale: 2, default: 0
      t.decimal :total_egresos, precision: 10, scale: 2, default: 0
      t.decimal :diferencia, precision: 10, scale: 2
      t.text :notas_apertura
      t.text :notas_cierre
      t.references :abierta_por, null: false, foreign_key: { to_table: :users }
      t.references :cerrada_por, foreign_key: { to_table: :users }
      t.datetime :cerrada_at

      t.timestamps
    end

    add_index :aperturas_caja, :numero, unique: true
    add_index :aperturas_caja, :fecha, unique: true
    add_index :aperturas_caja, :estado
  end
end
