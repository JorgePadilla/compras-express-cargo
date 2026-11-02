# C33-03 · El sello del resumen de las 6 de la tarde: a este paquete ya se le
# contó al cliente que salió. Es el mismo molde que `llegada_notificada_at`.
#
# Lo que ya salió antes de este deploy se sella acá, con su `fecha_enviado`.
# Si no, el primer resumen le cuenta a cada cliente todo lo que viajó desde
# abril. Va en la migración y no en seeds porque el deploy no siembra.
class AddEnvioNotificadoAtToPaquetes < ActiveRecord::Migration[8.0]
  def up
    add_column :paquetes, :envio_notificado_at, :datetime
    execute <<~SQL
      UPDATE paquetes SET envio_notificado_at = fecha_enviado WHERE fecha_enviado IS NOT NULL
    SQL
  end

  def down
    remove_column :paquetes, :envio_notificado_at
  end
end
