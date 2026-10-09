# A7-08 · La ventana de aviso al escanear el manifiesto interno, que existía en
# la conversación y no en el código porque no había cola (`RP-32`, «sin efecto»
# desde el 2026-09-01). Con la cola conectada, vuelve.
#
# Dos sellos, porque hay **dos que avisan** y ninguno puede repetir:
# - `paquetes.llegada_notificada_at`: a este paquete ya se le avisó. La ventana
#   avisa lo escaneado hasta ahí; cerrar después avisa solo a los que faltaban.
# - `manifiestos.aviso_llegada_programado_at`: el job se programa **una** vez,
#   con el primer paquete escaneado, no con cada uno.
class LaVentanaDeA708 < ActiveRecord::Migration[8.0]
  def change
    add_column :paquetes, :llegada_notificada_at, :datetime
    add_column :manifiestos, :aviso_llegada_programado_at, :datetime
  end
end
