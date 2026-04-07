class AddTituloProveedorToPreAlertasRemoveValorPesoFromPaquetes < ActiveRecord::Migration[8.0]
  def change
    add_column :pre_alertas, :titulo, :string
    add_column :pre_alertas, :proveedor, :string

    remove_column :pre_alerta_paquetes, :valor_declarado, :decimal, precision: 10, scale: 2
    remove_column :pre_alerta_paquetes, :peso, :decimal, precision: 10, scale: 2
  end
end
