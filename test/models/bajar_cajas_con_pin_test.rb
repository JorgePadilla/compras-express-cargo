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
    marcar_en_pre_factura(cajas.last)

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

  test "una caja que paso por una pre-factura ANULADA tambien se puede bajar" do
    # `PreFactura#anular!` pone `paquete.pre_factura_id` en nil pero DEJA los
    # items vivos. Ir por `caja.pre_factura` —lo obvio— no los encuentra, y el
    # `destroy!` revienta contra la FK: 500 en vez del aviso.
    cajas = crear_split(2)
    pf = pre_factura_con(cajas.last, subtotal: 500)
    pf.anular!

    assert PreFacturaItem.exists?(paquete_id: cajas.last.id), "el fixture no reproduce el caso"

    quedan = bajar(cajas.first, 1).call

    assert_equal [ 1 ], quedan.map(&:numero_caja)
    assert_not PreFacturaItem.exists?(paquete_id: cajas.last.id)
  end

  test "una caja en una pre-factura YA facturada tampoco" do
    cajas = crear_split(2)
    pf = pre_factura_con(cajas.last, subtotal: 500)
    pf.update_columns(estado: "facturado")

    assert_raises(BajarCajasConPin::YaFacturado) { bajar(cajas.first, 1).call }
    assert_equal 1, Paquete.where(id: cajas.last.id).count
  end

  test "el limite fiscal se mide por el ITEM, no por la asociacion" do
    # Defensa en profundidad, y fija la regla: lo que ata la caja al documento
    # es el `pre_factura_item`, no `paquete.pre_factura_id`. Que los dos lados
    # se separen ya pasa hoy con `anular!`; si algun dia pasara con una
    # facturada, mirar solo la asociacion borraria una caja ya facturada.
    cajas = crear_split(2)
    pf = pre_factura_con(cajas.last, subtotal: 500)
    pf.update_columns(estado: "facturado")
    cajas.last.update_columns(pre_factura_id: nil)

    assert_raises(BajarCajasConPin::YaFacturado) { bajar(cajas.first, 1).call }
    assert_equal 1, Paquete.where(id: cajas.last.id).count
  end

  # ── El PIN ──

  test "sin el PIN correcto no borra nada" do
    cajas = crear_split(2)
    marcar_en_pre_factura(cajas.last)

    error = assert_raises(BajarCajasConPin::PinInvalido) { bajar(cajas.first, 1, pin: "9999").call }

    assert_match(/PIN/, error.message)
    assert_equal 2, Paquete.where(numero_recepcion: cajas.first.numero_recepcion).count
  end

  test "la lista de roles sale de la respuesta de Yusef, no de un criterio nuestro" do
    # RP-21: escribio "SI" en los cuatro renglones —Administrador, Supervisor de
    # Caja, Supervisor de Pre-Factura, Supervisor de SAC—, que son exactamente
    # `ROLES_AUTORIZANTES`. Mas Julien (supervisor_miami), que ya lleva PIN por
    # PR-C6.28 y es donde nace el error.
    #
    # Si alguien vuelve a armarla a mano, este test lo agarra: la primera
    # version se habia comido a SAC.
    assert_equal (User::ROLES_AUTORIZANTES + [ "supervisor_miami" ]).sort,
                 BajarCajasConPin::ROLES.sort
  end

  test "el supervisor de SAC tambien puede" do
    # Yusef lo marco "SI" explicitamente y la primera version de la lista lo
    # dejaba afuera.
    cajas = crear_split(2)
    marcar_en_pre_factura(cajas.last)
    sac = User.create!(
      nombre: "Supervisora SAC", email_address: "sac.cajas@test.com",
      password: "password123", rol: "supervisor_sac", activo: true, pin: "1234"
    )

    quedan = bajar(cajas.first, 1, supervisor: sac).call

    assert_equal [ 1 ], quedan.map(&:numero_caja)
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
    marcar_en_pre_factura(cajas.last)

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

  # Antes esto era `estado: "pre_facturado"`. Con ese estado eliminado (A7-11),
  # lo que dice que una caja ya entró a cobro es la FK — que es lo que
  # `cobrada_o_entregada?` miraba de primero desde siempre. Y es más fiel: el
  # estado solo era un espejo de esta columna, y podía mentir.
  def marcar_en_pre_factura(caja)
    pf = PreFactura.create!(cliente: @cliente, estado: "creado",
                            creado_por: users(:cajero), fecha_trabajo: Date.current)
    caja.update_columns(estado: "disponible_entrega", pre_factura_id: pf.id)
  end

  def pre_factura_con(caja, subtotal:)
    pf = PreFactura.create!(cliente: @cliente, estado: "creado",
                            creado_por: users(:cajero), fecha_trabajo: Date.current)
    pf.pre_factura_items.create!(
      paquete: caja, concepto: "Flete caja #{caja.numero_caja}",
      peso_cobrar: 10, precio_libra: 50, subtotal: subtotal
    )
    caja.update_columns(pre_factura_id: pf.id, estado: "disponible_entrega")
    pf.reload.save!
    pf.reload
  end
end
