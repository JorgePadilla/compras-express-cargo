require "test_helper"

# PR-C6.41 · RP-04b: "cobrar solo volumen", por cliente y por servicio.
#
# Yusef, al margen del cuestionario: *"hay clientes que solo se les cobra
# volumen en ciertos servicios; necesita quedar editable por cliente y por
# servicio"*. Audio del 2026-08-08: son "mayoristas o clientes grandes", y la
# opción va "cuando creamos el cliente".
#
# Un cliente que manda cajas grandes y livianas paga por el espacio que ocupa en
# el contenedor, no por lo que pesa. Es una negociación comercial — por eso es
# por cliente y no una regla global.
class CobroSoloVolumetricoTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
    @cem = tipo_envios(:cem)
    @cer = tipo_envios(:cer)
  end

  # ── El flag ──

  test "sin fila el cliente no cobra solo volumetrico" do
    assert_not @cliente.cobra_solo_volumetrico?(@cem)
  end

  test "la fila prende el flag SOLO para ese servicio" do
    @cliente.tipo_envio_solo_volumetricos << @cem

    assert @cliente.cobra_solo_volumetrico?(@cem)
    assert_not @cliente.cobra_solo_volumetrico?(@cer),
      "el trato es por servicio: el mismo mayorista paga normal en los demas"
  end

  test "acepta el id ademas del objeto" do
    @cliente.tipo_envio_solo_volumetricos << @cem

    assert @cliente.cobra_solo_volumetrico?(@cem.id)
  end

  test "sin tipo de envio no aplica nada" do
    # `Paquete belongs_to :tipo_envio, optional: true`, asi que esto llega.
    @cliente.tipo_envio_solo_volumetricos << @cem

    assert_not @cliente.cobra_solo_volumetrico?(nil)
  end

  test "no deja duplicar el par cliente + servicio" do
    ClienteCobroVolumetrico.create!(cliente: @cliente, tipo_envio: @cem)

    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique) do
      ClienteCobroVolumetrico.create!(cliente: @cliente, tipo_envio: @cem)
    end
  end

  # ── El calculo ──

  test "el paquete de un cliente con el flag cobra el volumetrico aunque pese mas" do
    @cliente.tipo_envio_solo_volumetricos << @cem

    p = paquete_de(@cem, peso: 30, medidas: [ 8, 9, 9 ])  # 648 pulg3 → 4.0 VLbs

    assert_equal 4.0, p.peso_volumetrico.to_f
    assert_equal 4.0, p.peso_cobrar.to_f,
      "con el flag manda el volumetrico, no las 30 lb de la bascula"
  end

  test "el MISMO cliente en un servicio sin flag sigue cobrando el mayor" do
    # El assert cruzado: prueba que el trato es por servicio y no por cliente.
    @cliente.tipo_envio_solo_volumetricos << @cem

    p = paquete_de(@cer, peso: 30, medidas: [ 8, 9, 9 ])

    assert_equal 30.0, p.peso_cobrar.to_f
  end

  test "sin flag no cambia nada" do
    p = paquete_de(@cem, peso: 30, medidas: [ 8, 9, 9 ])

    assert_equal 30.0, p.peso_cobrar.to_f
  end

  test "sin medidas se cobra el peso real, NUNCA cero" do
    # El unico camino por el que esta feature podria regalar flete: el operario
    # pesa la caja pero todavia no teclea las medidas, el volumetrico es 0 y sin
    # el guard el paquete se factura gratis.
    @cliente.tipo_envio_solo_volumetricos << @cem

    p = paquete_de(@cem, peso: 30, medidas: nil)

    assert_equal 30.0, p.peso_cobrar.to_f
  end

  test "el volumetrico manda tambien cuando es MAYOR que el peso" do
    # No es que el flag "baje" el cobro: es que manda el volumetrico. Si la caja
    # es enorme y liviana, sigue cobrando el volumetrico — igual que el default.
    @cliente.tipo_envio_solo_volumetricos << @cem

    p = paquete_de(@cem, peso: 1, medidas: [ 8, 9, 9 ])

    assert_equal 4.0, p.peso_cobrar.to_f
  end

  # ── El cotizador (lo que /entrega_personal muestra como "Valor a pagar") ──

  test "el cotizador usa el mismo criterio que el paquete" do
    # Si se separan, la pantalla le muestra al operario un peso y la pre-factura
    # le cobra otro — el defecto que PR-10.a vino a cerrar.
    @cliente.tipo_envio_solo_volumetricos << @cem

    r = CotizadorFlete.call(tipo_envio: @cem, cliente: @cliente,
                            peso: 30, alto: 8, largo: 9, ancho: 9)

    assert_equal 4.0, r.peso_cobrar.to_f
  end

  test "el cotizador sin flag sigue tomando el mayor" do
    r = CotizadorFlete.call(tipo_envio: @cem, cliente: @cliente,
                            peso: 30, alto: 8, largo: 9, ancho: 9)

    assert_equal 30.0, r.peso_cobrar.to_f
  end

  test "el cotizador sin cliente no revienta" do
    r = CotizadorFlete.call(tipo_envio: @cem, cliente: nil,
                            peso: 30, alto: 8, largo: 9, ancho: 9)

    assert_equal 30.0, r.peso_cobrar.to_f
  end

  # ── El minimo del servicio sigue mandando ──

  test "el minimo del servicio se aplica igual sobre el peso volumetrico" do
    # Jorge lo cerro: el minimo es una regla del SERVICIO, no del peso. Si el
    # volumetrico deja el cobro por debajo, se cobra el minimo.
    @cliente.tipo_envio_solo_volumetricos << @cem

    tarifa = Tarifa.create!(
      tipo_envio: @cem, desde_libras: 0, precio_libra: 2.50, moneda: "USD",
      minimo_monto: 10, minimo_moneda: "USD", activo: true
    )

    cobro = tarifa.cobro_para(2.0)  # 2 lb × $2.50 = $5.00, debajo del minimo

    assert cobro[:aplico_minimo], "el minimo del servicio no depende de que peso mando"
    assert_equal 10.0, cobro[:subtotal].to_f
  end

  # ── Auditoria ──

  test "prender el flag queda auditado" do
    # Prenderlo BAJA lo que se le cobra al cliente. El audit de Cliente no ve
    # inserts de esta tabla, asi que sin `has_paper_trail` en el join no queda
    # rastro de quien le dio la tarifa especial a quien.
    assert_difference -> { PaperTrail::Version.where(item_type: "ClienteCobroVolumetrico").count }, 1 do
      ClienteCobroVolumetrico.create!(cliente: @cliente, tipo_envio: @cem)
    end
  end

  private

  def paquete_de(tipo_envio, peso:, medidas:)
    alto, largo, ancho = medidas
    Paquete.create!(
      tracking: "1Z#{SecureRandom.hex(5).upcase}",
      cliente: @cliente, sucursal: sucursales(:miami), tipo_envio: tipo_envio,
      peso: peso, alto: alto, largo: largo, ancho: ancho
    )
  end
end
