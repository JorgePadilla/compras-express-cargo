class CreateEgresosCaja < ActiveRecord::Migration[8.0]
  def change
    create_table :egresos_caja do |t|
      t.string :numero, null: false
      t.references :apertura_caja, null: false, foreign_key: { to_table: :aperturas_caja }
      t.decimal :monto, precision: 10, scale: 2, null: false
      t.string :concepto, null: false
      t.string :metodo_pago, null: false
      t.string :categoria
      t.text :notas
      t.references :registrado_por, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :egresos_caja, :numero, unique: true
  end
end
