# C28-08 · La medición es **de la tanda**, no de cada volumen.
#
# Hasta el 2026-10-03 cada volumen llevaba sus cajas (`paquetes.bulto_id`,
# `C27-10`): el operario escaneaba tres cajas, medía, escaneaba dos, medía. La
# línea de San Pedro lo probó en vivo y lo dio vuelta:
#
#   > "La medición la va a decidir después de haber escaneado."
#   > "Es como en Miami, que escaneaste un tracking y lo dices en tantos
#   >  paquetes. Y aquí es que vas a unir varios tracking y lo vas a hacer en
#   >  tantas mediciones."
#   > "Para ellos es mejor solo escanear, que sí están ahí, y ellos lo acomodan
#   >  como gustan para medir y pesar."
#
# Así que una caja ya no pertenece a un volumen: pertenece a la **tanda**, y la
# tanda tiene N volúmenes. `bultos.sesion` ya era la identidad de la tanda
# (única con `orden`, y la URL de sus etiquetas cuelga de ella), así que la caja
# guarda esa misma sesión y no hace falta una tabla nueva.
#
# El backfill copia la sesión del bulto de cada caja medida: las tandas viejas
# quedan leyéndose igual que las nuevas.
#
# `bulto_id` se queda en la tabla —el modelo lo ignora— y se borra en una
# migración posterior: el contenedor viejo sigue vivo un momento después de que
# `db:prepare` corre esto, y Rails inserta todas las columnas que conoce. La FK
# sí se va ya: sin el `dependent: :nullify` de antes, re-medir una tanda vieja
# borraría un bulto al que una caja todavía apunta.
class LaMedicionEsDeLaTanda < ActiveRecord::Migration[8.0]
  def up
    add_column :paquetes, :medicion_sesion, :string
    add_index :paquetes, :medicion_sesion

    execute <<~SQL
      UPDATE paquetes SET medicion_sesion = bultos.sesion
      FROM bultos WHERE paquetes.bulto_id = bultos.id
    SQL

    remove_foreign_key :paquetes, :bultos

    # Las tandas que `#449` dejó a medio reemplazar: re-medir el volumen 1 de
    # dos dejaba vivo el 2 diciendo «2 de 2». Se cuentan, no se tocan.
    rotas = select_value(<<~SQL).to_i
      SELECT count(*) FROM (
        SELECT sesion FROM bultos GROUP BY sesion HAVING count(*) <> max(de_cuantos)
      ) x
    SQL
    say "Tandas con volúmenes que no cuadran con su «de N»: #{rotas}" if rotas.positive?
  end

  def down
    add_foreign_key :paquetes, :bultos
    remove_index :paquetes, :medicion_sesion
    remove_column :paquetes, :medicion_sesion
  end
end
