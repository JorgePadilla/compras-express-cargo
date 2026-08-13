require "test_helper"

# PR-10.b: la cotización que ve el operario en /entrega_personal.
class CotizadorFleteTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
    @cer     = tipo_envios(:cer)
    Tarifa.delete_all
  end

  def a_lps(usd) = CurrencyAware.convertir(usd, de: "USD", a: "LPS")

  test "cotiza en Lempiras y expone el equivalente en dolares" do
    Tarifa.create!(tipo_envio: @cer, precio_libra: 4.50, moneda: "USD")

    r = CotizadorFlete.call(tipo_envio: @cer, cliente: @cliente, peso: 10)

    assert_equal "LPS", r.moneda
    assert_equal a_lps(4.50), r.precio_libra
    assert_equal (BigDecimal("10") * a_lps(4.50)).round(2), r.subtotal
    assert_in_delta 45.0, r.en_usd(r.subtotal).to_f, 0.05
  end

  test "suma el ISV al total" do
    Tarifa.create!(tipo_envio: @cer, precio_libra: 4.50, moneda: "USD")

    r = CotizadorFlete.call(tipo_envio: @cer, cliente: @cliente, peso: 10)

    assert_equal (r.subtotal * IsvAware.rate).round(2), r.impuesto
    assert_equal (r.subtotal + r.impuesto).round(2), r.total
  end

  test "usa el peso volumetrico cuando supera al real" do
    Tarifa.create!(tipo_envio: @cer, precio_libra: 1.00, moneda: "USD")

    # 20×20×20 = 8000 pulg³ / 166 = 48.19 → media libra → 48.5
    r = CotizadorFlete.call(tipo_envio: @cer, cliente: @cliente,
                            peso: 2, alto: 20, largo: 20, ancho: 20)

    assert_equal BigDecimal("48.5"), r.vlbs
    assert_equal BigDecimal("48.5"), r.peso_facturado
  end

  test "avisa cuando se aplico el minimo" do
    Tarifa.create!(tipo_envio: @cer, precio_libra: 4.50, moneda: "USD",
                   minimo_monto: 173.91, minimo_moneda: "LPS")

    r = CotizadorFlete.call(tipo_envio: @cer, cliente: @cliente, peso: 1)

    assert r.aplico_minimo
    assert_equal BigDecimal("173.91"), r.subtotal
  end

  # A7-25: antes cotizaba con la tabla vieja, o sea mostraba un precio distinto
  # del que la pre-factura iba a cobrar. Ahora devuelve cero y lo reporta: el
  # vacío se lee como "falta cargar la tarifa", no como "es gratis".
  test "sin tarifa cargada cotiza en cero y lo reporta" do
    r = CotizadorFlete.call(tipo_envio: @cer, cliente: @cliente, peso: 10)

    assert_not r.tarifa_encontrada?
    assert r.sin_tarifa
    assert_equal 0, r.subtotal
  end

  # ── La garantía que importa ──

  test "la cotizacion coincide con lo que termina cobrando la pre-factura" do
    Tarifa.create!(tipo_envio: @cer, precio_libra: 4.50, moneda: "USD",
                   minimo_monto: 173.91, minimo_moneda: "LPS")

    paquete = Paquete.create!(
      cliente: @cliente, tipo_envio: @cer, tracking: "1Z999COTIZA1",
      descripcion: "Test", peso: 3, alto: 10, largo: 12, ancho: 8,
      estado: "disponible_entrega", user: users(:admin)
    )

    cotizado = CotizadorFlete.call(tipo_envio: @cer, cliente: @cliente,
                                   peso: 3, alto: 10, largo: 12, ancho: 8)

    pf = PreFactura.build_from_paquetes(@cliente, [ paquete.id ], user: users(:admin))
    facturado = pf.pre_factura_items.find { |i| i.concepto.to_s.start_with?("Flete") }

    assert_equal facturado.subtotal.to_d, cotizado.subtotal,
                 "lo que se le muestra al operario tiene que ser lo que se cobra"
    assert_equal facturado.peso_cobrar.to_d, cotizado.peso_facturado
    assert_equal facturado.precio_libra.to_d, cotizado.precio_libra
  end
end
