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

  test "usa la tarifa de lista cuando no hay nada mas especifico" do
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD")
    p = paquete_con(peso: 10)

    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ], user: @user)

    assert_equal BigDecimal("45.00"), item_de_flete(pf).subtotal
  end

  test "aplica el minimo de monto y lo deja anotado en el concepto" do
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD",
                   minimo_monto: 20.00, minimo_moneda: "USD")
    p = paquete_con(peso: 1) # 4.50 < 20.00

    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ], user: @user)
    item = item_de_flete(pf)

    assert_equal BigDecimal("20.00"), item.subtotal
    assert_includes item.concepto, "mínimo de servicio"
    assert item.minimo_aplicado
  end

  test "el minimo sobrevive al guardado — no lo pisa calculate_subtotal_from_peso" do
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD",
                   minimo_monto: 20.00, minimo_moneda: "USD")
    p = paquete_con(peso: 1)

    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ], user: @user)
    pf.save!

    assert_equal BigDecimal("20.00"), item_de_flete(pf.reload).subtotal,
                 "el callback recalculaba 1 × 4.50 y borraba el minimo"
  end

  test "aplica el minimo de libras — el caso CEM/CKM" do
    Tarifa.create!(tipo_envio: tipo_envios(:ckm), precio_libra: 1.50, moneda: "USD",
                   minimo_libras: 20)
    p = paquete_con(peso: 2, tipo_envio: tipo_envios(:ckm))

    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ], user: @user)
    item = item_de_flete(pf)

    assert_equal BigDecimal("20.0"), item.peso_cobrar
    assert_equal BigDecimal("30.00"), item.subtotal
  end

  test "el precio especial del cliente gana sobre el de lista" do
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD")
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 2.00, moneda: "USD",
                   cliente: @cliente)
    p = paquete_con(peso: 10)

    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ], user: @user)

    assert_equal BigDecimal("20.00"), item_de_flete(pf).subtotal
  end

  test "sin ninguna tarifa cargada cae al comportamiento anterior" do
    p = paquete_con(peso: 10)

    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ], user: @user)

    esperado = @cliente.categoria_precio&.precio_para(tipo_envios(:cer)) ||
               tipo_envios(:cer).precio_libra
    assert_equal (BigDecimal("10") * esperado.to_d).round(2), item_de_flete(pf).subtotal
  end

  # ── Prepagado en Miami (PR-6b, sin cobertura hasta ahora) ──

  test "el cobro simbolico de prepagado en Miami sobrevive al guardado" do
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD")
    p = paquete_con(peso: 10, prepagado_miami: true)

    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ], user: @user)
    pf.save!

    item = item_de_flete(pf.reload)
    assert_equal PreFactura::PREPAGADO_MIAMI_SIMBOLICO, item.subtotal,
                 "se guardaba en 0 porque el callback hacia peso × 0"
    assert_includes item.concepto, "PREPAGADO EN MIAMI"
  end

  test "el paquete prepagado no se cobra por su peso" do
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD")
    p = paquete_con(peso: 10, prepagado_miami: true)

    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ], user: @user)
    pf.save!

    assert_equal PreFactura::PREPAGADO_MIAMI_SIMBOLICO, pf.reload.subtotal
  end
end
