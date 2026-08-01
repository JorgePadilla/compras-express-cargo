# PR-9.a: la franja de contexto en /etiquetar y /entrega_personal necesita
# mostrar las tareas del cliente ANTES de que exista el paquete. Hoy
# `tareas.paquete_id` es NOT NULL, así que una tarea no puede existir sin
# paquete.
#
# Cambios:
#   - cliente_id: la tarea puede colgar del cliente. `paquete_id` pasa a
#     opcional; el modelo valida que haya al menos uno de los dos.
#   - pre_alerta_paquete_id: idempotencia al sincronizar tareas desde
#     `pre_alerta_paquetes.instrucciones` (evita duplicar en cada guardado).
#   - departamento: miami | caja | honduras | sac. nil = visible para todos.
#     Misma segmentación que `User#notas_permanentes_visibles`.
#   - origen: manual | pre_alerta.
#   - bloquea_avance: `Paquete#no_advance_with_open_tareas` congela el avance
#     de estado si hay tareas abiertas. Como `crear_paquete_esperado` ya
#     materializa un Paquete al crear la pre-alerta, auto-crear tareas desde
#     `instrucciones` habría bloqueado la transición pre_alerta_estado →
#     empacado y roto /etiquetar para cualquier pre-alerta con instrucciones.
#     Las tareas de origen `pre_alerta` nacen con false; las manuales con
#     true; el backfill deja true todo lo preexistente para no cambiar el
#     comportamiento actual.
class AddClienteYDepartamentoATareas < ActiveRecord::Migration[8.0]
  def up
    add_reference :tareas, :cliente, foreign_key: true, index: true
    add_reference :tareas, :pre_alerta_paquete, foreign_key: true, index: true

    add_column :tareas, :departamento,   :string
    add_column :tareas, :origen,         :string,  null: false, default: "manual"
    add_column :tareas, :bloquea_avance, :boolean, null: false, default: true

    add_index :tareas, [ :cliente_id, :estado ]
    add_index :tareas, :departamento

    # Backfill: toda tarea existente cuelga de un paquete, así que hereda su
    # cliente. Se hace antes de relajar el NOT NULL para que ninguna quede
    # huérfana de ambos lados.
    execute <<~SQL
      UPDATE tareas
         SET cliente_id = paquetes.cliente_id
        FROM paquetes
       WHERE tareas.paquete_id = paquetes.id
         AND tareas.cliente_id IS NULL
    SQL

    change_column_null :tareas, :paquete_id, true
  end

  def down
    # Las tareas sin paquete (las de cliente) no pueden sobrevivir al
    # NOT NULL — se eliminan antes de restaurarlo.
    execute "DELETE FROM tareas WHERE paquete_id IS NULL"
    change_column_null :tareas, :paquete_id, false

    remove_index  :tareas, :departamento
    remove_index  :tareas, [ :cliente_id, :estado ]
    remove_column :tareas, :bloquea_avance
    remove_column :tareas, :origen
    remove_column :tareas, :departamento
    remove_reference :tareas, :pre_alerta_paquete, foreign_key: true
    remove_reference :tareas, :cliente, foreign_key: true
  end
end
