require "test_helper"

# Las tres reglas de mínimo tal como Yusef las dictó en el audio del
# 2026-08-02. Sirven de doble propósito: verifican que el modelo `Tarifa`
# pueda expresar lo que él describe, y le dan números concretos para validar.
#
#   "La tarifa de nosotros por libra es en dólares, pero las tarifas de mínimo
#    están basadas en lempiras algunas de ellas y otras en dólares."
#
#   "Serie CK, los servicios serie CK son 200 lempiras ya con ISV."
#
#   "El marítimo lo tenemos estipulado en cantidad de libras de acuerdo al
#    dólar. Le ponemos mínimo 3 libras o 4 libras."
#
#   "El express tiene un mínimo de $10... si es menos de libra y media es $10
#    más impuesto de venta."
#
#   "Todos los precios tienen que ser más impuesto de venta."
class TarifaReglasYusefTest < ActiveSupport::TestCase
  setup { Tarifa.delete_all }

  def total_con_isv(cobro_lps)
    (cobro_lps * (1 + IsvAware.rate)).round(2, BigDecimal::ROUND_HALF_UP)
  end

  # ── Serie CK: mínimo L.200 CON el ISV adentro ──
  # El neto que se guarda es 173.91; el ISV se suma al totalizar y devuelve
  # los 200 que Yusef conoce.
  test "serie CK cobra minimo de L.200 con ISV incluido" do
    t = Tarifa.new(tipo_envio: tipo_envios(:cka), precio_libra: 4.00, moneda: "USD",
                   minimo_moneda: "LPS")
    t.minimo_monto_con_isv = 200.00
    t.save!

    assert_equal BigDecimal("173.91"), t.minimo_monto, "la columna guarda el neto"

    cobro = t.cobro_para(0.5) # 0.5 lb × $4 = $2, muy por debajo del mínimo
    assert cobro[:aplico_minimo]
    assert_equal BigDecimal("173.91"), cobro[:subtotal]
    assert_equal "LPS", cobro[:moneda]

    # Y con el ISV encima vuelve a los 200 que él cobra en mostrador.
    assert_equal BigDecimal("200.00"), total_con_isv(cobro[:subtotal])
  end

  # ── Marítimo: el mínimo es en LIBRAS, no en dinero ──
  test "maritimo cobra un minimo de libras, no de monto" do
    t = Tarifa.create!(tipo_envio: tipo_envios(:cem), precio_libra: 2.50, moneda: "USD",
                       minimo_libras: 4)

    cobro = t.cobro_para(1.5)

    assert_equal BigDecimal("4"), cobro[:peso_facturado], "1.5 lb se cobra como 4"
    assert_equal BigDecimal("10.00"), cobro[:subtotal], "4 lb × $2.50"
    assert_not cobro[:aplico_minimo], "aca no aplico un piso de monto, sino de peso"
  end

  # ── Express: mínimo $10 SIN ISV incluido ──
  # Ojo el contraste con la serie CK: acá Yusef dice "$10 MÁS impuesto de
  # venta", así que el 10 ya es el neto y no se convierte.
  test "express cobra minimo de USD 10 mas ISV" do
    t = Tarifa.create!(tipo_envio: tipo_envios(:express), precio_libra: 8.00, moneda: "USD",
                       minimo_monto: 10.00, minimo_moneda: "USD")

    # "si es menos de libra y media" — a $8/lb, 1.25 lb da exactamente $10.
    liviano = t.cobro_para(1)
    assert liviano[:aplico_minimo]
    assert_equal BigDecimal("10.00"), liviano[:subtotal]

    # Por encima del punto de quiebre manda el peso, no el mínimo.
    pesado = t.cobro_para(3)
    assert_not pesado[:aplico_minimo]
    assert_equal BigDecimal("24.00"), pesado[:subtotal]
  end

  # ── El precio por libra siempre en dólares, el mínimo puede ir en cualquiera ──
  test "convive un precio en dolares con un minimo en lempiras" do
    t = Tarifa.create!(tipo_envio: tipo_envios(:cka), precio_libra: 4.00, moneda: "USD",
                       minimo_monto: 173.91, minimo_moneda: "LPS")

    assert_equal "USD", t.moneda
    assert_equal "LPS", t.minimo_moneda
    assert_equal "LPS", t.cobro_para(0.5)[:moneda],
                 "cuando gana el minimo, el cobro sale en la moneda del minimo"
  end

  # ── "Todos los precios tienen que ser más impuesto de venta" ──
  test "el ISV se aplica una sola vez, al totalizar" do
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD")
    cliente = clientes(:juan)
    paquete = Paquete.create!(cliente: cliente, tipo_envio: tipo_envios(:cer),
                              tracking: "1Z999ISVUNAVEZ", descripcion: "Test",
                              peso: 10, estado: "disponible_entrega", user: users(:admin))

    pf = PreFactura.build_from_paquetes(cliente, [ paquete.id ], user: users(:admin))
    pf.save!

    assert_equal (pf.subtotal * IsvAware.rate).round(2), pf.impuesto
    assert_equal (pf.subtotal + pf.impuesto).round(2), pf.total
  end
end
