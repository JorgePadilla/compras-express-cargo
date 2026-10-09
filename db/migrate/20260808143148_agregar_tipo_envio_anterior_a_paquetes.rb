# PR-C6.8: dejar rastro de qué servicio tenía el paquete antes del cambio.
#
# Hoy `solicito_cambio_servicio` es un booleano suelto: dice que alguien pidió
# el cambio, pero no de qué a qué. Y como el cambio genera un cargo automático
# en la pre-factura, cuando el cliente reclama no hay con qué contestarle.
class AgregarTipoEnvioAnteriorAPaquetes < ActiveRecord::Migration[8.0]
  def change
    add_reference :paquetes, :tipo_envio_anterior,
                  foreign_key: { to_table: :tipo_envios },
                  null: true,
                  index: true
  end
end
