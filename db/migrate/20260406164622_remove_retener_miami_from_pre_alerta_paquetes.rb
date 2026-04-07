class RemoveRetenerMiamiFromPreAlertaPaquetes < ActiveRecord::Migration[8.0]
  def change
    remove_column :pre_alerta_paquetes, :retener_miami, :boolean, default: false
  end
end
