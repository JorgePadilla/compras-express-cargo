# Los paquetes que se recibieron sin número de recepción.
#
# Yusef, 2026-08-26, con la etiqueta en la mano: *"algo falló ahí: no tiene el
# código de barras ni el número de recepción ni nada… la única que probé con
# una fue la que falló"* (`C18-04`). El esperado de una pre-alerta nace sin
# sucursal, y al recibirlo con una sola etiqueta se reusaba ya persistido: el
# número solo se generaba `on: :create`. `PR-C7.49` arregla el origen; esto
# numera lo que ya quedó grabado así.
#
# La lógica vive en `Paquete.numerar_recibidos_sin_numero!` y no acá: un
# método se testea, un archivo de migración no. El número sale del mes de
# `fecha_recibido_miami`: un recibido en julio que se numera hoy sale
# `RMIA2607…`, y está bien — es cuándo se recibió, no cuándo se arregló.
class NumerarRecibidosSinNumero < ActiveRecord::Migration[8.0]
  def up
    resultado = Paquete.numerar_recibidos_sin_numero!

    resultado[:numerados].each { |id, tracking, numero| say "paquete #{id} (#{tracking}) → #{numero}" }
    resultado[:saltados].each { |id, motivo| say "paquete #{id} SALTADO — #{motivo}" }
    resultado[:sin_sucursal].each { |id, tracking| say "paquete #{id} (#{tracking}) sin sucursal de recepción: no hay de dónde numerar" }
    say "#{resultado[:numerados].size} numerados, #{resultado[:saltados].size} saltados, #{resultado[:sin_sucursal].size} sin sucursal"
  end

  def down
    say "un número de recepción acuñado no se devuelve: esta migración no se deshace"
  end
end
