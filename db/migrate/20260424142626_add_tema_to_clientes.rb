class AddTemaToClientes < ActiveRecord::Migration[8.0]
  def change
    add_column :clientes, :tema, :string
  end
end
