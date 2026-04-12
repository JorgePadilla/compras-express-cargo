class AddFinanciamientoRefToVentas < ActiveRecord::Migration[8.0]
  def change
    add_reference :ventas, :financiamiento, foreign_key: true
  end
end
