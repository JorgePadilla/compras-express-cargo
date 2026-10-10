# PR-P.1 · La línea de la factura es **el volumen** (Fase 14, `C27-10`,
# `C27-15`).
#
# Hasta acá la pre-factura copiaba `paquete.peso_cobrar` —el peso de Miami— y
# nunca leía el de Medición. Una línea de flete por volumen apunta a su
# `Bulto`, y las cajas de la tanda van en L. 0.00 colgadas de la misma tanda,
# para que `confirmar!`, `facturar!` y `anular!` sigan sabiendo sus paquetes
# por el camino de siempre.
#
# La FK es `restrict`: volver a medir una tanda ya facturada no puede borrar el
# volumen que la cobra (`MedirBulto#reemplazar!` lo frena antes con un
# mensaje). `venta_items` lleva la misma columna porque la factura, el PDF y
# el portal del cliente agrupan las cajas bajo su volumen igual que la
# pre-factura, y una línea de volumen no tiene paquete del que sacarlo.
class LaLineaEsElVolumen < ActiveRecord::Migration[8.0]
  def change
    add_reference :pre_factura_items, :bulto, null: true, index: true,
                  foreign_key: { on_delete: :restrict }
    add_reference :venta_items, :bulto, null: true, index: true,
                  foreign_key: { on_delete: :restrict }
  end
end
