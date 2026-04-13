class AddBillingRefsToPaquetes < ActiveRecord::Migration[8.0]
  def change
    add_reference :paquetes, :pre_factura, foreign_key: true
    add_reference :paquetes, :venta, foreign_key: { to_table: :ventas }
  end
end
