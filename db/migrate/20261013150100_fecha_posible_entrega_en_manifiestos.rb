# C31-10 · La fecha que el cliente ve, puesta una vez para toda la carga del
# manifiesto. Yusef: *"vengo yo y me entero que no salió en el vuelo del martes
# sino que salió en el del jueves, entonces ¿qué tengo que hacer yo? Venir,
# actualizar… la fecha de todos los paquetes que están en ese manifiesto"*.
#
# Es **otra** columna que `fecha_aduana` («Recibido en Honduras»): ésa es el
# día en que nosotros la recibimos y no puede ser futura; ésta es una
# estimación y va para adelante o para atrás.
#
# Renumerada de 20261013150000, que chocó con la de `pre_facturas.etiquetas`
# (#536 y #538 salieron el mismo día con la misma versión y Rails no arranca
# con dos iguales). `unless column_exists?` por si alguna base alcanzó a
# correrla con el número viejo.
class FechaPosibleEntregaEnManifiestos < ActiveRecord::Migration[8.0]
  def up
    add_column :manifiestos, :fecha_posible_entrega, :date unless column_exists?(:manifiestos, :fecha_posible_entrega)
  end

  def down
    remove_column :manifiestos, :fecha_posible_entrega
  end
end
