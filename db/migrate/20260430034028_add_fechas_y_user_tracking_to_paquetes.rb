# PR-D1.b: agrega columnas de fechas faltantes para todo el ciclo del
# paquete + columna `*_by_user_id` por cada fecha (quién la disparó).
#
# Yusef (2026-04-29) confirmó:
# - Las fechas Empacado/Enviado/Aduana/Consolidando/Disponible se SOBREsCRIBEN
#   al actualizar; `fecha_pre_alerta` queda original (no sobrescribe).
# - Cada fecha trae las "iniciales de quien la disparó" — implementado como
#   FK al user que hizo el cambio.
# - paper_trail captura el histórico completo si alguien re-edita.
class AddFechasYUserTrackingToPaquetes < ActiveRecord::Migration[8.0]
  def change
    # ── Fechas nuevas ──
    add_column :paquetes, :fecha_solicito_recolecta, :datetime
    add_column :paquetes, :fecha_pre_alerta,         :datetime
    add_column :paquetes, :fecha_empacado,           :datetime
    add_column :paquetes, :fecha_aduana,             :datetime
    add_column :paquetes, :fecha_consolidando,       :datetime
    add_column :paquetes, :fecha_en_reparto,         :datetime
    add_column :paquetes, :fecha_entregado,          :datetime
    add_column :paquetes, :fecha_posible_entrega,    :datetime

    # ── Quién disparó cada fecha (FK a users) ──
    # Para fechas existentes (`fecha_recibido_miami`, `fecha_enviado`,
    # `fecha_disponible`) también agregamos el `*_by_user_id`.
    add_reference :paquetes, :fecha_recibido_miami_by_user, foreign_key: { to_table: :users }, index: false
    add_reference :paquetes, :fecha_enviado_by_user,        foreign_key: { to_table: :users }, index: false
    add_reference :paquetes, :fecha_disponible_by_user,     foreign_key: { to_table: :users }, index: false
    add_reference :paquetes, :fecha_solicito_recolecta_by_user, foreign_key: { to_table: :users }, index: false
    add_reference :paquetes, :fecha_pre_alerta_by_user,     foreign_key: { to_table: :users }, index: false
    add_reference :paquetes, :fecha_empacado_by_user,       foreign_key: { to_table: :users }, index: false
    add_reference :paquetes, :fecha_aduana_by_user,         foreign_key: { to_table: :users }, index: false
    add_reference :paquetes, :fecha_consolidando_by_user,   foreign_key: { to_table: :users }, index: false
    add_reference :paquetes, :fecha_en_reparto_by_user,     foreign_key: { to_table: :users }, index: false
    add_reference :paquetes, :fecha_entregado_by_user,      foreign_key: { to_table: :users }, index: false
    add_reference :paquetes, :fecha_posible_entrega_by_user, foreign_key: { to_table: :users }, index: false
  end
end
