require "test_helper"

# PR-C6.7: cambiar la cantidad de cajas de un split crea o elimina las que
# correspondan.
#
# `crear_split!` solo sabía **crear**. Yusef lo reprodujo dos veces en vivo:
#
#   · 3 cajas → lo bajó a 2 → quedaron las 3.
#   · Después lo subió a 5 → "aquí dice dos y aquí dice que son cinco".
#
# La regla que acordaron, y la cantidad nueva manda:
#
#   > **Jorge:** "Si tienes cinco y lo querés cambiar a dos, solo deberían
#   >  quedar los dos."
#   > **Yusef:** "Eliminar lo otro. Ajá."
class SplitAjustableTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
    @miami = sucursales(:miami)
  end

  test "bajar de 3 a 2 elimina la tercera" do
    cajas = crear_split(3)

    quedan = Paquete.ajustar_split!(cajas.first, 2)

    assert_equal [ 1, 2 ], quedan.map(&:numero_caja)
    assert_equal 0, Paquete.where(id: cajas.last.id).count, "la caja 3 sigue viva"
    assert quedan.all? { |c| c.cantidad_paquetes == 2 }, "quedaron diciendo 3 de 3"
  end

  test "subir de 2 a 5 crea las que faltan con el mismo numero madre" do
    cajas = crear_split(2)
    madre = cajas.first.numero_recepcion

    quedan = Paquete.ajustar_split!(cajas.first, 5)

    assert_equal [ 1, 2, 3, 4, 5 ], quedan.map(&:numero_caja)
    assert_equal [ madre ], quedan.map(&:numero_recepcion).uniq,
                 "las cajas nuevas nacieron con otro número madre"
    assert quedan.all? { |c| c.cantidad_paquetes == 5 }
  end

  test "el sintoma exacto que vio Yusef: no quedan registros de la cantidad vieja" do
    cajas = crear_split(3)

    Paquete.ajustar_split!(cajas.first, 2)
    todas = Paquete.where(numero_recepcion: cajas.first.numero_recepcion)

    assert_equal 2, todas.count
    assert_equal [ 2 ], todas.map(&:cantidad_paquetes).uniq,
                 "\"aquí dice dos y aquí dice que son cinco\""
  end

  test "dejarlo en la misma cantidad no toca nada" do
    cajas = crear_split(3)
    ids = cajas.map(&:id).sort

    quedan = Paquete.ajustar_split!(cajas.first, 3)

    assert_equal ids, quedan.map(&:id).sort
  end

  test "se puede ajustar desde cualquiera de las hermanas, no solo la primera" do
    cajas = crear_split(4)

    quedan = Paquete.ajustar_split!(cajas[2], 2)

    assert_equal [ 1, 2 ], quedan.map(&:numero_caja)
  end

  # ── La guarda dura ─────────────────────────────────────────────────────

  test "no se puede eliminar una caja ya facturada" do
    cajas = crear_split(3)
    cajas.last.update_columns(estado: "facturado")

    error = assert_raises(Paquete::CajaNoEliminable) do
      Paquete.ajustar_split!(cajas.first, 2)
    end

    assert_match(/caja 3/, error.message)
  end

  test "cuando falla no toca NADA" do
    # La transacción es la red: si se borró la caja 3 pero la 4 estaba
    # facturada, no puede quedar el split a medias.
    cajas = crear_split(4)
    cajas[3].update_columns(estado: "facturado")

    assert_raises(Paquete::CajaNoEliminable) { Paquete.ajustar_split!(cajas.first, 2) }

    assert_equal 4, Paquete.where(numero_recepcion: cajas.first.numero_recepcion).count,
                 "se borró alguna caja antes de fallar"
    assert_equal [ 4 ], Paquete.where(numero_recepcion: cajas.first.numero_recepcion)
                               .pluck(:cantidad_paquetes).uniq,
                 "quedaron diciendo una cantidad que no se aplicó"
  end

  test "bloquea tambien por FK de cobro, no solo por estado" do
    # Un paquete puede tener `pre_factura_id` sin que su estado lo diga
    # todavía. Mirar solo el estado dejaría borrar una caja ya pre-facturada.
    cajas = crear_split(2)
    cajas.last.update_columns(pre_factura_id: pre_facturas(:borrador_juan).id)

    assert_raises(Paquete::CajaNoEliminable) { Paquete.ajustar_split!(cajas.first, 1) }
  end

  test "una caja entregada tampoco se elimina" do
    cajas = crear_split(2)
    cajas.last.update_columns(estado: "entregado")

    assert_raises(Paquete::CajaNoEliminable) { Paquete.ajustar_split!(cajas.first, 1) }
  end

  test "si la caja bloqueada NO esta entre las que se van, el ajuste procede" do
    # La caja 1 facturada no impide bajar de 3 a 2: la que se va es la 3.
    cajas = crear_split(3)
    cajas.first.update_columns(estado: "facturado")

    quedan = Paquete.ajustar_split!(cajas.first, 2)

    assert_equal [ 1, 2 ], quedan.map(&:numero_caja)
  end

  private

  def crear_split(n)
    Paquete.crear_split!(
      attrs: {
        tracking: "AJU#{SecureRandom.hex(4)}",
        cliente: @cliente,
        sucursal_recepcion: @miami,
        estado: "empacado",
        descripcion: "Split de prueba",
        user: users(:digitador)
      },
      total_cajas: n
    )
  end
end
