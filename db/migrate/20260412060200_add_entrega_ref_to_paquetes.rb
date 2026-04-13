class AddEntregaRefToPaquetes < ActiveRecord::Migration[8.0]
  def change
    add_reference :paquetes, :entrega, null: true, foreign_key: true
  end
end
