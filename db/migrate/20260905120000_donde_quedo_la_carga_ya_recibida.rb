# C23-14 · Rellenar `sucursal_actual` de la carga que ya se recibió.
#
# La columna dice *"ubicación física actual"* y la escribía **un solo lugar**:
# la recepción del manifiesto **interno**. La carga que entra de Miami —o sea
# toda la que llega al país— pasaba a `en_aduana` sin dejar dicho en qué
# sucursal aterrizó, así que la columna quedaba en `nil` justo para el 100% del
# inventario.
#
# Desde ahora la estampa `RecibirManifiesto#mover_a_aduana`. Esta migración le
# pone la que le tocaba a lo que ya estaba recibido, que **se deriva sin
# inventar nada**: es la `sucursal_entrega` del manifiesto que lo trajo.
#
# Solo toca filas con `sucursal_actual` en nil y que cuelgan de un manifiesto
# con sucursal de entrega. Lo que no cumple eso se queda como está: no hay de
# dónde sacarlo, y poner una sucursal a dedo sería peor que dejarlo vacío.
class DondeQuedoLaCargaYaRecibida < ActiveRecord::Migration[8.0]
  def up
    actualizados = execute(<<~SQL).cmd_tuples
      UPDATE paquetes p
         SET sucursal_actual_id = m.sucursal_entrega_id
        FROM manifiestos m
       WHERE p.manifiesto_id = m.id
         AND p.sucursal_actual_id IS NULL
         AND m.sucursal_entrega_id IS NOT NULL
         AND p.estado IN ('en_aduana', 'disponible_entrega', 'facturado')
    SQL

    say "paquetes con su sucursal actual puesta: #{actualizados}"
  end

  # Irreversible: bajarla tendría que **borrar** la sucursal de paquetes, y no
  # hay forma de saber cuáles llenó esta migración y cuáles se llenaron después
  # al recibirlos de verdad.
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
