# A7-11 · *"El prefacturado no sé de dónde lo sacó. Yo creo que lo sacó de los
# procesos, **no del estatus. Ese tenés que eliminar.**"*
#
# Los paquetes que lo tienen puesto pasan a `disponible_entrega`, que es el paso
# que la pre-factura describe en el orden de `A7-01` (*"bodega Honduras va
# después de prefactura"*) y lo que `PreFactura#confirmar!` escribe desde ahora.
#
# Va por migración de datos y no por seeds porque el deploy de staging solo
# migra. `estado` es una columna de texto sin CHECK: el enum vive en el modelo,
# así que sin este `UPDATE` los paquetes viejos quedarían con un valor que Rails
# ya no sabe leer y `paquete.estado` reventaría al instanciarlos.
class EliminarEstadoPreFacturado < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE paquetes
         SET estado = 'disponible_entrega'
       WHERE estado = 'pre_facturado';
    SQL
  end

  # Irreversible a propósito: no hay forma de saber cuáles de los
  # `disponible_entrega` estaban en `pre_facturado` antes. Quien necesite
  # deshacerlo tiene el dato en `pre_factura_id`, que es justamente el punto.
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
