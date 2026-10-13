# C31-11 · «Posible fecha de entrega» en días hábiles, con feriados.
#
# Yusef, mostrando el correo del sistema viejo: *"es días calendario y no días
# hábiles"*. Para contar días hábiles hacen falta dos datos que no existían:
#
# - **cuántos días** tarda cada servicio. Hoy viven en `tipo_envios.sla`, que es
#   texto libre para leer («6-10 dias habiles»). Yusef: *"para mí debería estar
#   donde vos tengas los tipos de servicio"*. Va un entero aparte, que se edita
#   desde /servicios; el `sla` se queda como está porque lo leen otras pantallas.
# - **los feriados**, que el equipo de Yusef carga: *"una vez ya quedan
#   grabados. Bueno, se pueden modificar… porque cambian la semana morazánica,
#   la semana santa"*. Una fecha no se repite.
#
# El llenado de `dias_entrega` va en la migración siguiente: el deploy de Render
# migra pero no siembra.
class DiasDeEntregaYFeriados < ActiveRecord::Migration[8.0]
  def change
    add_column :tipo_envios, :dias_entrega, :integer

    create_table :feriados do |t|
      t.date :fecha, null: false
      t.string :nombre, null: false
      t.timestamps

      t.index :fecha, unique: true
    end
  end
end
