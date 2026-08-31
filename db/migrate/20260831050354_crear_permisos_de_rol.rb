# `RP-58` · Las **excepciones** al mapa de permisos que trae el código.
#
# Yusef: *"siempre necesitamos que nosotros podamos editar el rol y los roles
# que tiene [cada puesto]… editar el título del rol y lo que ellos puedan y no
# puedan"*, y el costo de no tenerlo: *"si no, te vamos a estar molestando con
# que necesitamos quitar y poner… y te vamos a tener en ese relajo"*.
#
# ── Por qué guarda excepciones y no la matriz entera ──────────────────────
#
# Con **cero filas la conducta es exactamente la de hoy**, por construcción: sin
# fila manda `PermisosDelSistema.politica`. No hace falta sembrar 9 × 38 = 342
# filas ni una migración de datos que las mantenga.
#
# Y evita un problema que la matriz completa sí tiene: si estuviera toda
# sembrada, cambiar la política en el código no cambiaría nada **en silencio**,
# porque cada celda tendría su fila pisándola. Así, la celda que nadie tocó
# sigue al código para siempre, y la que sí se tocó la pantalla la marca.
#
# Borrar una fila = volver al código. Es la operación de «deshacer».
class CrearPermisosDeRol < ActiveRecord::Migration[8.0]
  def change
    create_table :permisos_de_rol do |t|
      t.string  :rol,      null: false
      t.string  :seccion,  null: false
      t.boolean :permitido, null: false
      t.timestamps
    end

    # Una sola excepción por par. El índice único es la regla, no un adorno:
    # dos filas contradictorias para el mismo par harían que el permiso dependa
    # del orden en que salgan de la base.
    add_index :permisos_de_rol, %i[rol seccion], unique: true
  end
end
