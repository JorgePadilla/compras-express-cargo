require "test_helper"

# PR-C6.42 · RP-18: bajar la cantidad de cajas cuando alguna ya entró a cobro,
# con el PIN de un supervisor.
#
# Yusef marcó ☒ *"Que deje hacerlo, pero solo con PIN de supervisor"*, y dio el
# caso real:
#
#   > "Le pusieron 2 y al final es un paquete, y cuando van a entregar, el
#   >  sistema no va a querer entregar porque decía que eran dos."
#
# La guarda de `ajustar_split!` es correcta —borrar una caja cobrada
# descuadraría la venta— pero deja el paquete **trabado**: la caja fantasma no
# existe físicamente, así que nadie la va a entregar nunca.
class BajarCajasConPinTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
    @miami = sucursales(:miami)
    @supervisor = users(:admin)
    @supervisor.update!(pin: "1234")
  end

  # ── El caso de Yusef ──

  test "el supervisor con su PIN baja una caja que ya estaba pre-facturada" do
    cajas = crear_split(2)
    cajas.last.update_columns(estado: "pre_facturado")

    # Sin PIN esto es exactamente lo que hoy traba el paquete.
    assert_raises(Paquete::CajaNoEliminable) { Paquete.ajustar_split!(cajas.first, 1) }

    quedan = bajar(cajas.first, 1).call

    assert_equal [ 1 ], quedan.map(&:numero_caja)
    assert_equal 0, Paquete.where(id: cajas.last.id).count, "la caja fantasma sigue viva"
    assert_equal 1, cajas.first.reload.cantidad_paquetes
  end

  test "saca la caja de la pre-factura abierta y recalcula el total" do
    # Borrarla a secas dejaria al cliente pagando una caja que ya no existe —
    # y encima el destroy chocaria contra la FK de pre_factura_items.
    cajas = crear_split(2)
    pf = pre_factura_con(cajas.last, subtotal: 500)
    total_antes = pf.total

    bajar(cajas.first, 1).call

    assert_equal 0, pf.reload.pre_factura_items.where(paquete_id: cajas.last.id).count
    assert_operator pf.total, :<, total_antes, "el total se quedó cobrando la caja borrada"
  end

  # ── Lo que ni el PIN destraba ──

  test "una caja ya facturada no se baja ni con PIN" do
    cajas = crear_split(2)
    cajas.last.update_columns(estado: "facturado")

    error = assert_raises(BajarCajasConPin::YaFacturado) { bajar(cajas.first, 1).call }

    assert_match(/nota de crédito/, error.message)
    assert_equal 1, Paquete.where(id: cajas.last.id).count
  end

  test "una caja ya entregada tampoco" do
    # Eso es un hecho fisico, no un error de digitacion.
    cajas = crear_split(2)
    cajas.last.update_columns(estado: "entregado")

    assert_raises(BajarCajasConPin::YaFacturado) { bajar(cajas.first, 1).call }
    assert_equal 1, Paquete.where(id: cajas.last.id).count
  end

  test "una caja en una pre-factura YA facturada tampoco" do
    cajas = crear_split(2)
    pf = pre_factura_con(cajas.last, subtotal: 500)
    pf.update_columns(estado: "facturado")

    assert_raises(BajarCajasConPin::YaFacturado) { bajar(cajas.first, 1).call }
    assert_equal 1, Paquete.where(id: cajas.last.id).count
  end

  # ── El PIN ──

  test "sin el PIN correcto no borra nada" do
    cajas = crear_split(2)
    cajas.last.update_columns(estado: "pre_facturado")

    error = assert_raises(BajarCajasConPin::PinInvalido) { bajar(cajas.first, 1, pin: "9999").call }

    assert_match(/PIN/, error.message)
    assert_equal 2, Paquete.where(numero_recepcion: cajas.first.numero_recepcion).count
  end

  test "un rol fuera de la lista no puede" do
    cajas = crear_split(2)
    digitador = users(:digitador)
    digitador.update!(pin: "1234")

    assert_raises(BajarCajasConPin::NoPermitido) { bajar(cajas.first, 1, supervisor: digitador).call }
    assert_equal 2, Paquete.where(numero_recepcion: cajas.first.numero_recepcion).count
  end

  test "un supervisor sin PIN asignado tampoco" do
    cajas = crear_split(2)
    @supervisor.update_columns(pin_digest: nil)

    assert_raises(BajarCajasConPin::NoPermitido) { bajar(cajas.first, 1).call }
  end

  test "un supervisor inactivo tampoco" do
    cajas = crear_split(2)
    @supervisor.update!(activo: false)

    assert_raises(BajarCajasConPin::NoPermitido) { bajar(cajas.first, 1).call }
  end

  test "sin supervisor tampoco" do
    cajas = crear_split(2)

    assert_raises(BajarCajasConPin::NoPermitido) { bajar(cajas.first, 1, supervisor: nil).call }
  end

  # ── Los bordes de la cantidad ──

  test "no sirve para SUBIR la cantidad" do
    # Subir nunca estuvo bloqueado: `ajustar_split!` lo hace sin PIN. Este
    # flujo es solo la valvula de escape para bajar.
    cajas = crear_split(2)

    assert_raises(BajarCajasConPin::NadaQueBajar) { bajar(cajas.first, 3).call }
  end

  test "no sirve para dejar la misma cantidad" do
    cajas = crear_split(2)

    assert_raises(BajarCajasConPin::NadaQueBajar) { bajar(cajas.first, 2).call }
  end

  test "no deja bajar a cero" do
    cajas = crear_split(2)

    assert_raises(BajarCajasConPin::NadaQueBajar) { bajar(cajas.first, 0).call }
    assert_equal 2, Paquete.where(numero_recepcion: cajas.first.numero_recepcion).count
  end

  # ── Auditoria ──

  test "el borrado queda auditado" do
    cajas = crear_split(2)
    cajas.last.update_columns(estado: "pre_facturado")

    assert_difference -> { PaperTrail::Version.where(item_type: "Paquete", event: "destroy").count }, 1 do
      bajar(cajas.first, 1).call
    end
  end

  private

  def bajar(paquete, cantidad, supervisor: :default, pin: "1234")
    BajarCajasConPin.new(
      paquete: paquete, cantidad: cantidad,
      supervisor: supervisor == :default ? @supervisor : supervisor,
      pin: pin, motivo: "se ingresaron 2 y al final era una"
    )
  end

  def crear_split(n)
    Paquete.crear_split!(
      attrs: {
        tracking: "BAJ#{SecureRandom.hex(4)}",
        cliente: @cliente,
        sucursal_recepcion: @miami,
        estado: "empacado",
        descripcion: "Split de prueba",
        user: users(:digitador)
      },
      total_cajas: n
    )
  end

  def pre_factura_con(caja, subtotal:)
    pf = PreFactura.create!(cliente: @cliente, estado: "creado",
                            creado_por: users(:cajero), fecha_trabajo: Date.current)
    pf.pre_factura_items.create!(
      paquete: caja, concepto: "Flete caja #{caja.numero_caja}",
      peso_cobrar: 10, precio_libra: 50, subtotal: subtotal
    )
    caja.update_columns(pre_factura_id: pf.id, estado: "pre_facturado")
    pf.reload.save!
    pf.reload
  end
end
