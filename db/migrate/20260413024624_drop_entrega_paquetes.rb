class DropEntregaPaquetes < ActiveRecord::Migration[8.0]
  def up
    drop_table :entrega_paquetes
  end

  def down
    create_table :entrega_paquetes do |t|
      t.references :entrega, null: false, foreign_key: true
      t.references :paquete, null: false, foreign_key: true
      t.timestamps
    end
    add_index :entrega_paquetes, %i[entrega_id paquete_id], unique: true
  end
end
