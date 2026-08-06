# PR-10.e: Yusef marcó un error de etiquetado en /entrega_personal —
# "aquí tenés mal: aquí es proveedor y aquí es el driver".
#
# `proveedor` es la EMPRESA que mandó el paquete ("viene Walmart y te manda el
# driver" — Jorge; "sí, correcto" — Yusef). El driver es la PERSONA que lo
# trajo físicamente al mostrador, y hasta ahora no tenía dónde guardarse: el
# formulario fusionaba los dos conceptos en un label "Proveedor / Driver".
#
# Va como texto libre y no como catálogo: "es donde tiene que ser editable,
# que es el driver". Cambia en cada entrega, así que un catálogo sería
# fricción — distinto de `Proveedor`, que sí es recurrente.
#
# Se imprime en la etiqueta: "igual otro driver para poner el nombre del
# driver en caso de tenerlo, por el rótulo".
class AddDriverAPaquetes < ActiveRecord::Migration[8.0]
  def change
    add_column :paquetes, :driver, :string
  end
end
