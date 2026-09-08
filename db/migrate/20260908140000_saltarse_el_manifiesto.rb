# C27-14 · Dejar medir una caja que **no pasó por el manifiesto**, con el sello
# de quién lo dejó pasar.
#
# Yusef, el 2026-09-07, dos veces y la segunda mirándolo pasar en vivo:
#
#   "Este tiene un bloqueo ahorita que me tiene loco: **si no ha pasado el
#    proceso desde Miami para acá, no lo puede hacer.** Y ya le dije que **le
#    tiene que eliminar eso** porque nos va a llevar putas, porque **a más de
#    alguno se le va a escapar. Hay que poner una opción ahí.**"
#
# Y antes, discutiéndolo con Jorge:
#
#   — Jorge: "Tenés que pasar el proceso de aduana, no podés saltarte el
#     proceso de manifiesto."
#   — Yusef: "Pero si ya está en Honduras. ¿Cómo llegó a Honduras si no…?
#     **Debe dejar que sí se lo salten, porque a veces se capean.**"
#
# Es la misma forma que `C26-03` («facturar lo que hay») y que
# `DescartarDeMedicion`: **avisar, dejar pasar y sellar**. No se le toca el
# estado al paquete —seguiría mintiendo—; lo que se guarda es la excepción:
# quién la autorizó, cuándo, y **en qué estado estaba la caja**, que es el dato
# que después se audita.
#
# El «ya está en una pre-factura» **no** se toca: ahí el peso se congeló y
# medirlo mentiría. Ese sí sigue siendo un no rotundo.
class SaltarseElManifiesto < ActiveRecord::Migration[8.0]
  def change
    add_column :paquetes, :salto_manifiesto_at, :datetime
    add_column :paquetes, :salto_manifiesto_por, :string
    add_column :paquetes, :salto_manifiesto_estado, :string
  end
end
