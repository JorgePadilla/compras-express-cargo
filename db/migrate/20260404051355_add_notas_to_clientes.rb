class AddNotasToClientes < ActiveRecord::Migration[8.0]
  def change
    add_column :clientes, :notas_miami, :text
    add_column :clientes, :notas_honduras, :text
  end
end
