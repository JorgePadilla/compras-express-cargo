# PR-13.a: la bandera que PR-10.a le puso a `pre_factura_items` hace falta en
# los otros tres documentos, y su ausencia era un cobro de menos en la factura
# real.
#
# `VentaItem`, `NotaCreditoItem` y `NotaDebitoItem` tienen el mismo
# `before_validation` que recalcula `subtotal = peso_cobrar × precio_libra`,
# pero ninguno mira si el monto vino de un mínimo. Así que:
#
#   - Un CER de 0.5 lb: la pre-factura dice L.173.91 (el mínimo del servicio) y
#     al facturar `VentaItem` lo pisa con 0.5 × L.111.83 = **L.55.92**. El
#     documento que efectivamente cobra sale a un tercio.
#   - El cobro simbólico de prepagado en Miami: `PreFacturaItem` lo construye
#     con `precio_libra: 0` y `minimo_aplicado: true`, y al facturar el callback
#     lo devuelve a **$0**. PR-10.a arregló ese caso a medias — del lado de la
#     pre-factura, no del de la venta.
#
# Mientras las tarifas eran el backfill plano de PR-10.a ningún mínimo estaba
# cargado y esto no se notaba. Con la tabla real de Yusef (PR-10.g) todo
# paquete chico se factura de menos.
class AddMinimoAplicadoADocumentosDeCobro < ActiveRecord::Migration[8.0]
  def change
    add_column :venta_items,         :minimo_aplicado, :boolean, null: false, default: false
    add_column :nota_credito_items,  :minimo_aplicado, :boolean, null: false, default: false
    add_column :nota_debito_items,   :minimo_aplicado, :boolean, null: false, default: false
  end
end
