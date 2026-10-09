# PR-C6.37: dónde retira el cliente, como dato y no como texto libre.
#
# Yusef, 2026-08-08, sobre separar las cajas por sucursal en Miami:
#
#   > "Recordá que **la ciudad donde es la persona no es el mismo lugar donde
#   >  se le entrega**. La idea es ponerle **dónde el hombre va a querer su
#   >  retiro**."
#
# El paquete ya tenía `sucursal_id` —él mismo lo dijo: "ese mismo, no es que
# vas a crear algo más"— pero nadie lo llenaba en /etiquetar, así que la
# etiqueta caía al `ciudad` del cliente, que es texto libre. Con eso, "Tegus" y
# "Tegucigalpa" son dos bolsas distintas en Miami.
#
# Lo que faltaba era el **default del cliente**: dónde quiere retirar. De ahí
# lo hereda el paquete al etiquetarlo.
class AgregarSucursalRetiroAClientes < ActiveRecord::Migration[8.0]
  def up
    add_reference :clientes, :sucursal_retiro, foreign_key: { to_table: :sucursales }

    # Backfill: la `ciudad` que ya venían escribiendo, cuando calza con el
    # nombre de una sucursal. Lo que no calce queda en nil y lo corrige un
    # admin — inventar una sucursal por un texto parecido sería peor que
    # dejarlo vacío.
    say_with_time "backfill desde clientes.ciudad" do
      execute(<<~SQL)
        UPDATE clientes c
           SET sucursal_retiro_id = s.id
          FROM sucursales s
         WHERE c.sucursal_retiro_id IS NULL
           AND c.ciudad IS NOT NULL
           AND lower(btrim(c.ciudad)) = lower(btrim(s.nombre))
      SQL
    end
  end

  def down
    remove_reference :clientes, :sucursal_retiro, foreign_key: { to_table: :sucursales }
  end
end
