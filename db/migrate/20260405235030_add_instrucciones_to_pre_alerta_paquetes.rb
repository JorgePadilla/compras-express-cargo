class AddInstruccionesToPreAlertaPaquetes < ActiveRecord::Migration[8.0]
  def change
    add_column :pre_alerta_paquetes, :instrucciones, :text
  end
end
