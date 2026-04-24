class CreateReempaques < ActiveRecord::Migration[8.0]
  def change
    create_table :reempaques do |t|
      t.references :paquete, null: false, foreign_key: true
      t.references :hecho_por, foreign_key: { to_table: :users }
      t.references :tarea, foreign_key: true

      t.decimal :alto_antes, precision: 8, scale: 2
      t.decimal :largo_antes, precision: 8, scale: 2
      t.decimal :ancho_antes, precision: 8, scale: 2
      t.decimal :peso_antes, precision: 10, scale: 2

      t.decimal :alto_despues, precision: 8, scale: 2
      t.decimal :largo_despues, precision: 8, scale: 2
      t.decimal :ancho_despues, precision: 8, scale: 2
      t.decimal :peso_despues, precision: 10, scale: 2

      t.text :notas
      t.datetime :realizado_en

      t.timestamps
    end
  end
end
