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

  # ── C20-11 · las dos columnas que se llaman como una asociación ──────────
  #
  # Jorge, 2026-08-29, con los logs de staging: *"al actualizar varias veces da
  # error, cuando actualizamos el número de etiquetas a más y más"*.
  #
  # `paquetes.proveedor` (string legacy) y `paquetes.pre_factura` (boolean
  # legacy) se llaman igual que `belongs_to :proveedor` y `belongs_to
  # :pre_factura`. Rails le da `proveedor=` a la asociación, así que copiar
  # `attributes` por `create!` mandaba el string al writer equivocado: con NULL
  # pasaba de casualidad, con "" o con "Amazon" era `AssociationTypeMismatch`.
  # Y el update escribe "" en esa columna cada vez, así que la *segunda*
  # subida de cajas era la que reventaba.

  test "subir cajas hereda el proveedor legacy, por la puerta correcta" do
    cajas = crear_split(2)
    cajas.first.update_column(:proveedor, "Amazon")

    quedan = Paquete.ajustar_split!(cajas.first, 4)

    # Las que faltaban nacen de la caja 1; a las hermanas que ya existían las
    # pone al día el controller (`propagar_envio_a_hermanas`), no este método.
    nuevas = quedan.select { |c| c.numero_caja > 2 }.map(&:reload)
    assert_equal [ "Amazon", "Amazon" ], nuevas.map { |c| c[:proveedor] },
                 "las cajas nuevas perdieron el origen que sale en la etiqueta"
    assert nuevas.all? { |c| c.proveedor.nil? }, "el string legacy no es un Proveedor del catálogo"
  end

  test "el \"\" que deja cualquier update en la columna legacy no revienta la subida" do
    # El caso exacto de staging (paquetes 182 y 195 del 2026-08-29).
    cajas = crear_split(2)
    cajas.first.update_column(:proveedor, "")

    assert_nothing_raised { Paquete.ajustar_split!(cajas.first, 3) }
    assert_equal 3, Paquete.where(numero_recepcion: cajas.first.numero_recepcion).count
  end

  test "el flag legacy pre_factura no se hereda, igual que pre_factura_id" do
    cajas = crear_split(2)
    cajas.first.update_column(:pre_factura, true)

    quedan = Paquete.ajustar_split!(cajas.first, 3)

    nueva = quedan.last.reload
    assert_equal false, nueva[:pre_factura], "una caja nueva no está pre-facturada"
    assert_nil nueva.pre_factura_id
  end

  test "las columnas que chocan con una asociación son exactamente las que ajustar_split! maneja a mano" do
    chocan = Paquete.column_names & Paquete.reflect_on_all_associations.map { |a| a.name.to_s }

    assert_equal %w[pre_factura proveedor], chocan.sort,
                 "apareció otra columna con nombre de asociación: por `create!(attributes)` " \
                 "va al writer de la asociación. Mirá cómo `ajustar_split!` trata a `proveedor`."
  end

  # ── C20-12 · «si ya tiene peso, obligarlo a llenar» ──────────────────────
  #
  # Yusef, 2026-08-30, cuando Jorge le llevó `RP-51`: *"si no tiene pesos, pues
  # los ponemos sin pesos; pero si ya tiene pesos tenemos que obligarlo a
  # llenar, para evitar esta incoherencia"*. La incoherencia: una caja de 5 lb
  # partida en tres nacía como tres cajas de 5 lb. Acá va la mitad del modelo:
  # las cajas nuevas no copian nada de lo que es de cada caja, y `por_caja:`
  # pesa cada una. Obligar es cosa del controller.

  test "subir cajas no copia el peso ni las medidas de la caja 1" do
    cajas = crear_split(2)
    cajas.first.update_columns(peso: 5, alto: 10, largo: 20, ancho: 30, cantidad_productos: 3)

    quedan = Paquete.ajustar_split!(cajas.first, 4)

    nuevas = quedan.select { |c| c.numero_caja > 2 }.map(&:reload)
    Paquete::CAMPOS_POR_CAJA.each do |campo|
      assert nuevas.all? { |c| c[campo].nil? }, "la caja nueva heredó #{campo}: tres cajas de 5 lb"
    end
    assert_equal 5, cajas.first.reload.peso.to_i, "la caja 1 no pierde lo suyo"
  end

  test "por_caja pesa cada caja, la original incluida" do
    cajas = crear_split(2)
    cajas.first.update_columns(peso: 5)

    quedan = Paquete.ajustar_split!(cajas.first, 3,
                                    por_caja: { 1 => { peso: "2" }, 2 => { peso: "2" }, 3 => { peso: "1.5" } })

    assert_equal [ 2.0, 2.0, 1.5 ], quedan.map { |c| c.reload.peso.to_f },
                 "el peso de la caja sola era el del envío: después de reempacar ya no vale"
  end

  test "por_caja solo acepta lo que es de cada caja" do
    cajas = crear_split(2)

    Paquete.ajustar_split!(cajas.first, 2, por_caja: { "2" => { "peso" => "3", "descripcion" => "pisada" } })

    assert_equal 3.0, cajas.last.reload.peso.to_f
    assert_equal "Split de prueba", cajas.last.descripcion, "un dato del envío entró por la puerta de la caja"
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
