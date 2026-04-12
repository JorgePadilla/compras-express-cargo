class AddAperturaCajaRefToPagos < ActiveRecord::Migration[8.0]
  def change
    add_reference :pagos, :apertura_caja, null: true, foreign_key: { to_table: :aperturas_caja }
  end
end
