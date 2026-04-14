class AddFinalizadoHistorialToPreAlertas < ActiveRecord::Migration[8.0]
  def change
    add_column :pre_alertas, :finalizado, :boolean, default: false, null: false
    add_column :pre_alertas, :historial, :text
  end
end
