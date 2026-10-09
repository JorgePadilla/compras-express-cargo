# C21-07 · Recibir la carga en Honduras.
#
# Cierra el hueco más grande que tenía el sistema, el que `lib/procesos_pdf.rb`
# marcaba con `existe: false` y la frase *"hoy se cambia el estado a mano"*, y
# que `RP-30` preguntaba. Yusef ya lo había decidido en la Conversación 7
# (`A7-03`…`A7-08`) y la 21 le puso quién y con qué:
#
#   > "Los de prefactura, ellos son los que se encargan de recibir carga."
#   > "Es mejor una pantallita que ahí buscara y que **solo le aparezca lo que
#   >  tiene que meter**… solo lo que está como enviado."
#   > "Aquí es donde yo te digo que quiero **el aparatito**: que vengan ellos,
#   >  llegan a recibir carga, y **escanean la caja** y automáticamente el
#   >  sistema lo [pone]."
#
# Se escanean **cajas, no paquetes** (`A7-06`), y al completar todo pasa a
# aduana — que es lo mismo que él escribió a mano sobre la etiqueta 4×6:
# *«se escanea al recibir en HN → actualiza estatus de paquetes de ENVIADO →
# ADUANA»*.
class RecepcionDeCarga < ActiveRecord::Migration[8.0]
  def change
    change_table :caja_manifiestos, bulk: true do |t|
      t.datetime :recibida_at
      t.references :recibida_por, foreign_key: { to_table: :users }
    end
    add_column :manifiestos, :recepcion_finalizada_at, :datetime
  end
end
