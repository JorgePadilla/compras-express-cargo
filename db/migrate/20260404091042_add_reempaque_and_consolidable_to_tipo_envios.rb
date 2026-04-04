class AddReempaqueAndConsolidableToTipoEnvios < ActiveRecord::Migration[8.0]
  def change
    add_column :tipo_envios, :con_reempaque, :boolean, default: false, null: false
    add_column :tipo_envios, :consolidable, :boolean, default: false, null: false
  end
end
