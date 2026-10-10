# PR-F1.8 · Las secuencias de número de recepción por sucursal, que ya nadie usa.
#
# `20260425033302` creó una secuencia por sucursal (`numero_recepcion_rm_seq`,
# `…_rs_seq`, `…_rh_seq`) **por cada sucursal que hubiera en la base ese día**.
# Al día siguiente `20260425225919` las reemplazó por `numero_recepcion_counters`
# (PR-A, formato anual; después por mes, PR-C6.40), y desde entonces ningún
# `nextval('numero_recepcion_…')` existe en el código.
#
# Quedaron como basura que depende de los datos: la base de quien hizo el dump
# las tenía, una base migrada desde cero no (no tiene sucursales cuando corre
# esa migración), y por eso `structure.sql` no salía igual migrando desde cero.
# Se borran donde estén, con el nombre que tengan.
#
# Solo las **sueltas**: `numero_recepcion_counters_id_seq` también empieza
# igual, y es la clave de la tabla de contadores — esa pertenece a una columna
# (`pg_depend` con `deptype = 'a'`) y no se toca.
class QuitarSecuenciasDeRecepcionMuertas < ActiveRecord::Migration[8.0]
  def up
    muertas = select_values(<<~SQL)
      SELECT c.relname
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relkind = 'S'
        AND n.nspname = 'public'
        AND c.relname LIKE 'numero\\_recepcion\\_%\\_seq'
        AND NOT EXISTS (
          SELECT 1 FROM pg_depend d
          WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid AND d.deptype = 'a'
        )
      ORDER BY c.relname
    SQL

    muertas.each { |nombre| execute "DROP SEQUENCE IF EXISTS #{quote_table_name(nombre)}" }
    say muertas.any? ? "secuencias borradas: #{muertas.join(', ')}" : "no había secuencias de recepción sueltas"
  end

  # No se recrean: ningún código las lee, y el valor que tenían salía de los
  # datos de cada base.
  def down; end
end
