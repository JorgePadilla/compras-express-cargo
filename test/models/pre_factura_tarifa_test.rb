require "test_helper"

# PR-10.a: la pre-factura ahora cobra con `Tarifa` en vez de la cadena
# categoria_precio → tipo_envio. Estos tests fijan los mínimos y el caso
# prepagado, que hasta ahora no tenía ninguna cobertura.
class PreFacturaTarifaTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
    @user    = users(:admin)
    Tarifa.delete_all
  end

  # Paquete facturable: en bodega Honduras y sin pre-factura previa.
  def paquete_con(peso:, tipo_envio: tipo_envios(:cer), **extra)
    Paquete.create!({
      cliente: @cliente, tipo_envio: tipo_envio,
      tracking: "1Z#{SecureRandom.hex(6).upcase}",
      descripcion: "Test", peso: peso, estado: "disponible_entrega",
      user: @user
    }.merge(extra))
  end

  def item_de_flete(pf)
    pf.pre_factura_items.find { |i| i.concepto.to_s.start_with?("Flete") }
  end

  # Las tarifas están en USD y la pre-factura en Lempiras, así que los montos
  # esperados se expresan como conversión y no como números mágicos.
  def tasa = CurrencyAware.tasa_vigente
  def a_lps(usd) = CurrencyAware.convertir(usd, de: "USD", a: "LPS")

  test "la pre-factura nace en Lempiras" do
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD")
    p = paquete_con(peso: 10)

    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ], user: @user)
    pf.save!

    assert_equal "LPS", pf.moneda
    assert_equal tasa, pf.tasa_cambio_aplicada.to_d, "la tasa queda congelada en el documento"
  end

  test "convierte el precio en dolares a la moneda del documento" do
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD")
    p = paquete_con(peso: 10)

    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ], user: @user)
    item = item_de_flete(pf)

    assert_equal a_lps(4.50), item.precio_libra,
                 "antes guardaba 4.50 y lo mostraba como si fueran Lempiras"
    assert_equal (BigDecimal("10") * a_lps(4.50)).round(2), item.subtotal
  end

  test "la factura cuadra a la vista del cliente: peso x precio = subtotal" do
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD")
    p = paquete_con(peso: 7)

    item = item_de_flete(PreFactura.build_from_paquetes(@cliente, [ p.id ], user: @user))

    assert_equal (item.peso_cobrar.to_d * item.precio_libra.to_d).round(2), item.subtotal.to_d
  end

  test "aplica el minimo de monto y lo deja anotado en el concepto" do
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD",
                   minimo_monto: 20.00, minimo_moneda: "USD")
    p = paquete_con(peso: 1) # 4.50 < 20.00

    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ], user: @user)
    item = item_de_flete(pf)

    assert_equal a_lps(20.00), item.subtotal
    assert_includes item.concepto, "mínimo de servicio"
    assert item.minimo_aplicado
  end

  test "el minimo sobrevive al guardado — no lo pisa calculate_subtotal_from_peso" do
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD",
                   minimo_monto: 20.00, minimo_moneda: "USD")
    p = paquete_con(peso: 1)

    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ], user: @user)
    pf.save!

    assert_equal a_lps(20.00), item_de_flete(pf.reload).subtotal,
                 "el callback recalculaba 1 × 4.50 y borraba el minimo"
  end

  test "un minimo en Lempiras con precio en dolares no se convierte dos veces" do
    # El caso real: CER cobra $4.50/lb con mínimo de L.200 (neto L.173.91).
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD",
                   minimo_monto: 173.91, minimo_moneda: "LPS")
    p = paquete_con(peso: 1)

    item = item_de_flete(PreFactura.build_from_paquetes(@cliente, [ p.id ], user: @user))

    assert_equal BigDecimal("173.91"), item.subtotal,
                 "el mínimo ya estaba en Lempiras: debe llegar tal cual al documento"
  end

  test "aplica el minimo de libras — el caso CEM/CKM" do
    Tarifa.create!(tipo_envio: tipo_envios(:ckm), precio_libra: 1.50, moneda: "USD",
                   minimo_libras: 20)
    p = paquete_con(peso: 2, tipo_envio: tipo_envios(:ckm))

    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ], user: @user)
    item = item_de_flete(pf)

    assert_equal BigDecimal("20.0"), item.peso_cobrar
    assert_equal (BigDecimal("20") * a_lps(1.50)).round(2), item.subtotal
  end

  test "el precio especial del cliente gana sobre el de lista" do
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD")
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 2.00, moneda: "USD",
                   cliente: @cliente)
    p = paquete_con(peso: 10)

    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ], user: @user)

    assert_equal (BigDecimal("10") * a_lps(2.00)).round(2), item_de_flete(pf).subtotal
  end

  # A7-25: ya no hay "comportamiento anterior" al que caer. La tabla vieja no se
  # consulta, así que sin tarifa la línea sale en cero y lo dice en el concepto.
  test "sin ninguna tarifa cargada la linea sale en cero y avisa" do
    p = paquete_con(peso: 10)

    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ], user: @user)
    # No entra por `item_de_flete`: el concepto ya no arranca con "Flete"
    # justamente para que salte a la vista.
    item = pf.pre_factura_items.first

    assert_equal 0, item.subtotal
    assert_match(/SIN TARIFA/i, item.concepto)
  end

  # ── Prepagado en Miami (PR-6b, sin cobertura hasta ahora) ──

  test "el cobro simbolico de prepagado en Miami sobrevive al guardado" do
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD")
    p = paquete_con(peso: 10, prepagado_miami: true)

    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ], user: @user)
    pf.save!

    item = item_de_flete(pf.reload)
    assert_equal a_lps(PreFactura::PREPAGADO_MIAMI_SIMBOLICO), item.subtotal,
                 "se guardaba en 0 porque el callback hacia peso × 0"
    assert_includes item.concepto, "PREPAGADO EN MIAMI"
  end

  test "el paquete prepagado no se cobra por su peso" do
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD")
    p = paquete_con(peso: 10, prepagado_miami: true)

    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ], user: @user)
    pf.save!

    assert_equal a_lps(PreFactura::PREPAGADO_MIAMI_SIMBOLICO), pf.reload.subtotal
  end
end
