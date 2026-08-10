# PR-C6.40: el número de recepción pasa a llevar sucursal y mes.
#
# Yusef lo escribió a mano en la pregunta 17, rotulando cada parte:
#
#     R        MIA        26     12     ______________
#     prefijo  sucursal   año    mes    correlativo
#
# El cambio de fondo no es el formato sino ESTE contador: hoy la clave es
# (sucursal, año) y el correlativo reinicia cada 1° de enero. Pasa a reiniciar
# cada mes, así que la clave necesita el mes.
#
# Las filas viejas quedan con `mes = 0`, que es el valor que nunca va a usar un
# mes real (1-12). Así el contador anual del año pasado no choca con el de
# enero y no hay que borrar historia.
class ContadorDeRecepcionPorMes < ActiveRecord::Migration[8.0]
  def up
    add_column :numero_recepcion_counters, :mes, :integer, null: false, default: 0

    remove_index :numero_recepcion_counters, column: %i[sucursal_id anio]
    add_index :numero_recepcion_counters, %i[sucursal_id anio mes], unique: true,
              name: "index_numero_recepcion_counters_por_mes"
  end

  def down
    remove_index :numero_recepcion_counters, name: "index_numero_recepcion_counters_por_mes"
    execute "DELETE FROM numero_recepcion_counters WHERE mes <> 0"
    add_index :numero_recepcion_counters, %i[sucursal_id anio], unique: true
    remove_column :numero_recepcion_counters, :mes
  end
end
