# PR-13.b: el descuento como dato propio.
#
# Hoy un descuento se hace bajándole el precio a la línea, así que es invisible:
# la factura sale con un precio más bajo y nada dice que hubo descuento, ni de
# cuánto, ni quién lo dio. La vista de pre-factura incluso lo documenta — el
# input de subtotal tiene el tooltip "Editable para descuentos autorizados".
#
# Yusef va a autorizar descuentos con su PIN (Fase 13), y mal se puede autorizar
# algo que después no queda registrado en ningún lado.
#
# `descuento_monto` es el número autoritativo: es lo que suma y lo que se
# imprime. `descuento_porcentaje` es descriptivo — solo se llena si se capturó
# como %, para que la factura pueda decir "Descuento (10%)". Guardar el monto
# calculado y no derivarlo del % en cada lectura evita un segundo redondeo sobre
# un número que ya está en la factura.
class AddDescuentoADocumentosDeCobro < ActiveRecord::Migration[8.0]
  def change
    %i[pre_factura_items venta_items].each do |tabla|
      add_column tabla, :descuento_monto, :decimal, precision: 10, scale: 2,
                        null: false, default: 0
      add_column tabla, :descuento_porcentaje, :decimal, precision: 5, scale: 2
      add_column tabla, :descuento_motivo, :string
    end

    # El acumulado, para el bloque de totales del documento.
    %i[pre_facturas ventas].each do |tabla|
      add_column tabla, :descuento, :decimal, precision: 10, scale: 2,
                        null: false, default: 0
    end
  end
end
