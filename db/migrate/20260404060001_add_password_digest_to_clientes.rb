class AddPasswordDigestToClientes < ActiveRecord::Migration[8.0]
  def change
    add_column :clientes, :password_digest, :string
  end
end
