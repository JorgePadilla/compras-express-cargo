# C17-02: la tarea que se deja desde la franja de /etiquetar mientras se recibe
# un paquete, antes de que el paquete exista.
#
# Jorge (2026-08-26): la tarea de la franja **se ata al paquete al guardarlo**.
# «Revisar el contenido de esta caja» que queda colgando del cliente no bloquea
# el avance de ninguna caja. La franja guarda acá el tracking que había en
# pantalla, y `Tarea.atar_al_paquete!` la re-apunta al guardar — el mismo
# re-apunte que `PreAlertaPaquete.link_tracking!` hacía con las de pre-alerta.
#
# Normalizado en mayúsculas al escribir (`Tarea#normalizar_tracking`) para que
# el índice sirva: un btree bajo `UPPER()` no.
class TrackingEnTareas < ActiveRecord::Migration[8.0]
  def change
    add_column :tareas, :tracking, :string
    add_index :tareas, :tracking, where: "tracking IS NOT NULL"
  end
end
