# `RP-58` paso 2b · El **título** del rol, editable.
#
# Yusef: *"editar el título del rol y lo que ellos puedan y no puedan"*. Lo
# segundo lo resolvió el paso 1; esto es lo primero.
#
# Guarda **solo lo renombrado**, igual que `permisos_de_rol`: con cero filas la
# conducta es idéntica a hoy por construcción —manda `User::ROL_DESCRIPTIONS`—,
# no hace falta migración de datos que mantenga una copia, y borrar la fila es
# la operación de «volver al nombre del sistema».
#
# **El código del rol no se toca.** `supervisor_caja` sigue llamándose
# `supervisor_caja` en el enum, en `PermisosDelSistema.politica` y en cada
# constante `*_ROLES`. Lo que se vuelve data es cómo se lee, no qué significa.
class CrearTitulosDeRol < ActiveRecord::Migration[8.0]
  def change
    create_table :titulos_de_rol do |t|
      t.string :rol, null: false
      t.string :titulo, null: false
      t.string :descripcion

      t.timestamps
    end

    add_index :titulos_de_rol, :rol, unique: true
  end
end
