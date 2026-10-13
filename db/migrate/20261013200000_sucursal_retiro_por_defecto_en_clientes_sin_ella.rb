# C31 · Los clientes que todavía no tienen «Sucursal donde retira» pasan a la
# de retiro por defecto: San Pedro, Zerón.
#
# Yusef, en la conversación del 2026-10-12 (audio 15:32, min 12–18), mirando
# casilleros sin sucursal: *"cuando no tiene sucursal esto debería ser San
# Pedro, y se centraliza todo a la Zerón… va a ser default en algún futuro,
# pero ahorita default San Pedro Zerón"*. Y Jorge, el 2026-10-13: que el campo
# quede siempre lleno.
#
# Al crear un cliente ya se exige (C29-03, en /clientes y en el registro del
# portal); lo que quedaba vacío son los de antes. Ésta es **migración de
# datos** y no seed porque el deploy no siembra.
#
# La sucursal sale de la marcada `retiro_por_defecto` en /sucursales; si nadie
# marcó ninguna, de la de código `SPS`. Si no hay ninguna de las dos (una base
# vacía), no hace nada: inventarle una sucursal a un cliente sería peor que
# dejarlo como está. Solo toca los que están en nil; no hay `down` que
# devuelva el nil, porque no se sabe cuáles eran.
class SucursalRetiroPorDefectoEnClientesSinElla < ActiveRecord::Migration[8.0]
  def up
    defecto = select_value(<<~SQL)
      SELECT id FROM sucursales
       WHERE retiro_por_defecto = TRUE
       ORDER BY id LIMIT 1
    SQL
    defecto ||= select_value("SELECT id FROM sucursales WHERE codigo = 'SPS' ORDER BY id LIMIT 1")
    return say("no hay sucursal de retiro por defecto ni SPS: no se toca nada") if defecto.nil?

    say_with_time "clientes sin sucursal de retiro → sucursal #{defecto}" do
      update("UPDATE clientes SET sucursal_retiro_id = #{Integer(defecto)}, updated_at = NOW() " \
             "WHERE sucursal_retiro_id IS NULL")
    end
  end

  def down
    # Irreversible a propósito: no hay registro de cuáles estaban vacíos.
  end
end
