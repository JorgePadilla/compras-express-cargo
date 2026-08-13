class AddFechaEnviadoSucursalAPaquetes < ActiveRecord::Migration[8.0]
  # A7-09. El estado `enviado_sucursal` existe **para auditar**: sirve para
  # encontrar el paquete que se quedó sin empacar. Sin fecha ni autor no sirve
  # de nada — "este sale pendiente, hay que buscarlo" necesita saber desde
  # cuándo y quién lo despachó.
  #
  # Sigue la convención de `ESTADO_FECHA_MAP`: `fecha_<estado>` +
  # `fecha_<estado>_by_user_id`.
  def change
    add_column :paquetes, :fecha_enviado_sucursal, :datetime
    add_reference :paquetes, :fecha_enviado_sucursal_by_user,
                  foreign_key: { to_table: :users }, null: true, index: true
  end
end
