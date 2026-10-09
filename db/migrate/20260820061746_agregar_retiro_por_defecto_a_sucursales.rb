# Cuál es la sucursal a la que va la carga si nadie dice lo contrario.
#
# Yusef, 2026-08-19, mirando el aviso de «guardar en la bolsa de San Pedro Sula»:
#
#   > *"Esa de San Pedro Sula hay que eliminarlo, porque es el default."*
#   > *"El cerebro trabaja en default. Cuando querés que haga una cosa diferente
#   >  al default, tenés que ponerle la nota que es diferente."*
#
# El 80% de la carga se queda en San Pedro. Un aviso que sale siempre deja de
# leerse — y entonces tampoco se lee el día que dice Tegucigalpa, que es el único
# día en que importaba.
#
# Se **backfillea con los datos**, no a mano: la sucursal de retiro que más
# clientes tienen asignada. Si mañana abren otra y se corre el peso, se cambia
# desde `/sucursales` sin tocar código.
class AgregarRetiroPorDefectoASucursales < ActiveRecord::Migration[8.0]
  def up
    add_column :sucursales, :retiro_por_defecto, :boolean, default: false, null: false

    mayoritaria = Cliente.where.not(sucursal_retiro_id: nil)
                         .group(:sucursal_retiro_id)
                         .order(Arel.sql("COUNT(*) DESC"))
                         .limit(1)
                         .count
                         .keys
                         .first

    if mayoritaria
      Sucursal.where(id: mayoritaria).update_all(retiro_por_defecto: true)
      say "sucursal por defecto: #{Sucursal.find(mayoritaria).nombre}"
    else
      say "ningún cliente tiene sucursal de retiro: queda sin default, y el aviso sale siempre"
    end
  end

  def down
    remove_column :sucursales, :retiro_por_defecto
  end
end
