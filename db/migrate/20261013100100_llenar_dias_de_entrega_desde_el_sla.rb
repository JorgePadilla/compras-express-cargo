# C31-11 · Los días de entrega de cada servicio, sacados del `sla` que ya
# tenían escrito: «3-7 dias habiles» → 7, «6-10…» → 10, «14-17…» → 17.
#
# Se toma el **tope** del rango y no el piso: la fecha que se le da al cliente es
# una promesa, y es mejor que el paquete llegue antes que después. El equipo de
# Yusef lo corrige desde /servicios si no es así.
#
# Solo llena los que están vacíos, así que correrla otra vez no pisa lo que
# alguien ya editó. Un tipo sin `sla` (los legados inactivos) queda sin días, y
# para él el correo sigue diciendo lo de antes.
class LlenarDiasDeEntregaDesdeElSla < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE tipo_envios
         SET dias_entrega = (regexp_match(sla, '(\\d+)\\D*$'))[1]::integer
       WHERE dias_entrega IS NULL
         AND sla ~ '\\d'
    SQL
  end

  def down
    # Nada: la columna se va con la migración anterior.
  end
end
