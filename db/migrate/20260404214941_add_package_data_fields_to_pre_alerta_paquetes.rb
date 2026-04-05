class AddPackageDataFieldsToPreAlertaPaquetes < ActiveRecord::Migration[8.0]
  def change
    add_column :pre_alerta_paquetes, :valor_declarado, :decimal, precision: 10, scale: 2
    add_column :pre_alerta_paquetes, :peso,            :decimal, precision: 10, scale: 2
  end
end
