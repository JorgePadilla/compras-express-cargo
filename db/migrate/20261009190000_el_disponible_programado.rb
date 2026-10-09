# PR-P.2 · Disponible programado (Fase 14, `C30-16`, PR-D1 §A, `A7-16`).
#
# Yusef, el 2026-10-09: la pre-factura se termina en la tarde y el aviso le
# sale al cliente **a la hora de la fecha de trabajo** —7:30 por defecto—. Hasta
# esa hora los paquetes siguen en aduana; a esa hora el sistema los pasa a
# `disponible_entrega` y le escribe al cliente.
#
# - `notificar_at`: la fecha de trabajo con hora, segundos en cero (`C30-08`).
#   `fecha_trabajo` se queda y se mantiene igual a su día: los filtros la leen.
# - `notificado_at`: el sello de idempotencia. Editar después del aviso no lo
#   vuelve a mandar (*"su factura fue editada"* ×5).
# - `consolidando_at`: F8 (PR-P.6) es un momento, no un estado nuevo:
#   `facturar!` y los filtros por estado no se tocan.
# - `auditado_por_id`: quién la auditó escaneando (PR-P.5).
# - `notificacion_error`: un aviso que falla no frena a los demás (la lección
#   de PR-C29.19), y queda dicho por qué.
#
# El índice parcial es el del barrido de cada minuto: solo mira las que
# todavía no avisaron, que con el tiempo son casi ninguna.
class ElDisponibleProgramado < ActiveRecord::Migration[8.0]
  def change
    add_column :pre_facturas, :notificar_at, :datetime
    add_column :pre_facturas, :notificado_at, :datetime
    add_column :pre_facturas, :consolidando_at, :datetime
    add_reference :pre_facturas, :auditado_por, null: true, foreign_key: { to_table: :users }, index: true
    add_column :pre_facturas, :notificacion_error, :text
    add_index :pre_facturas, :notificar_at, where: "notificado_at IS NULL",
              name: "index_pre_facturas_por_avisar"
  end
end
