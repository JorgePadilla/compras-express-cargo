class AddV4FieldsToTipoEnvios < ActiveRecord::Migration[8.0]
  def change
    add_column :tipo_envios, :precio_libra, :decimal, precision: 10, scale: 2
    add_column :tipo_envios, :modalidad, :string
    add_column :tipo_envios, :sla, :string
    add_column :tipo_envios, :max_paquetes_por_accion, :integer
  end
end
