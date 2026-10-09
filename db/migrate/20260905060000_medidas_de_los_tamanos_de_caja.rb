# C21-04 · Las medidas de los tamaños pre-definidos, sacadas del sistema viejo.
#
# Los diez tamaños se sembraron el 2026-08-31 **sin medidas**, porque no las
# teníamos: solo «Mini D» se pudo derivar del `595.78` que muestra la pantalla
# vieja. Los otros ocho quedaron en nil, y con ellos el catálogo pre-llenaba
# nada — que es justo lo que Yusef pidió que hiciera: *"te ponen solo el cursor
# a peso, porque es lo que le vas a meter a ingresar"*.
#
# El 2026-09-05, con Jorge mirando, salieron del propio sistema viejo: el editor
# de manifiestos publica el viewmodel `TamanoCajasPredefinidoVM` en la página y
# ahí están las nueve con `Alto`, `Largo` y `Ancho`. «Mini D» coincidió exacta
# con la que habíamos derivado (46×43×50), que es la mejor señal de que la
# derivación era buena.
#
# **Esta migración solo rellena lo que está en nil.** Si Miami ya midió una caja
# y corrigió el catálogo a mano, esa medida gana: el dato de quien tiene la
# cinta en la mano vale más que el del sistema que estamos reemplazando.
#
# La lista vive en `lib/catalogos_del_manifiesto.rb`, como la de `PR-417`, y no
# copiada acá: tenerla dos veces es cómo se separan.
class MedidasDeLosTamanosDeCaja < ActiveRecord::Migration[8.0]
  def up
    require Rails.root.join("lib/catalogos_del_manifiesto")
    creados = CatalogosDelManifiesto.sembrar!
    say "tamaños medidos: #{creados[:tamanos_medidos]}" if creados[:tamanos_medidos].to_i.positive?
  end

  # Irreversible a propósito, igual que la que sembró los catálogos: bajarla
  # tendría que **borrar medidas**, y no hay forma de saber cuáles puso esta
  # migración y cuáles corrigió alguien después.
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
