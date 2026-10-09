# PR-C6.5: separar "dónde se recibió" de "dónde retira el cliente".
#
# `paquetes.sucursal_id` venía significando las dos cosas a la vez:
#
#   · "RETIRA EN" en la etiqueta (`etiqueta_helper.rb`), el listado y el
#     warehouse receipt — y además la búsqueda de tarifa en `PreFactura`.
#   · el prefijo del número de recepción (`RMI` = Recibido Miami).
#
# Son distintas: un paquete se **recibe** en Miami y se **retira** en Zeron
# SPS. Una sola columna no puede ser las dos, y el choque dejaba a
# `/etiquetar` sin poder asignar ninguna — que es la razón de fondo de que
# ningún paquete etiquetado en Miami tuviera número de recepción.
#
# `sucursal_id` no se toca: sigue siendo "retira en". Esta columna nueva es la
# que manda el número.
class AgregarSucursalRecepcionAPaquetes < ActiveRecord::Migration[8.0]
  def change
    add_reference :paquetes, :sucursal_recepcion,
                  foreign_key: { to_table: :sucursales },
                  null: true,
                  index: true
  end
end
