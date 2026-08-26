# Las tareas que el cliente "creó" sin saberlo.
#
# Yusef, 2026-08-25, viendo salir en el modal de /etiquetar una tarea con el
# texto de sus propias instrucciones: *"el cliente no puede poner una tarea,
# solo nosotros"* (`C16-01`). `PR-9` convertía las `instrucciones` de cada
# renglón de pre-alerta en una Tarea; ese código se fue en `PR-C7.41`, y esto
# limpia lo que dejó.
#
# La lógica vive en `Tarea.borrar_las_nacidas_de_instrucciones!` y no acá: un
# método se testea, un archivo de migración no. Solo borra las **abiertas**: las
# ya realizadas llevan quién y cuándo las marcó, y esa evidencia se queda.
class BorrarTareasNacidasDeInstrucciones < ActiveRecord::Migration[8.0]
  def up
    borradas = Tarea.borrar_las_nacidas_de_instrucciones!

    borradas.each { |titulo| say titulo }
    say "#{borradas.size} tareas nacidas de instrucciones borradas"
  end

  def down
    say "no se deshace: eran tareas que el cliente nunca quiso crear"
  end
end
