class AddNotificarFacturasToClientes < ActiveRecord::Migration[8.0]
  def change
    add_column :clientes, :notificar_facturas, :boolean, default: true, null: false
  end
end
