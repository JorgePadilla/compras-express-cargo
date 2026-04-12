class CreateFinanciamientoCuotas < ActiveRecord::Migration[8.0]
  def change
    create_table :financiamiento_cuotas do |t|
      t.references :financiamiento, null: false, foreign_key: true
      t.integer :numero_cuota, null: false
      t.decimal :monto, precision: 10, scale: 2, null: false
      t.string  :estado, null: false, default: "pendiente"
      t.date    :fecha_vencimiento, null: false
      t.datetime :pagada_at
      t.references :pago, foreign_key: true
      t.text :notas
      t.timestamps
    end

    add_index :financiamiento_cuotas, [:financiamiento_id, :numero_cuota], unique: true, name: "idx_fin_cuotas_unique"
  end
end
