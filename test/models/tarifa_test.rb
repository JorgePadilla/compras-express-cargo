require "test_helper"

# PR-10.a: las reglas de cobro que Yusef describió el 2026-08-02.
class TarifaTest < ActiveSupport::TestCase
  setup do
    @cer = tipo_envios(:cer)       # aéreo
    @cem = tipo_envios(:cem)       # marítimo
    @juan = clientes(:juan)
    Tarifa.delete_all
  end

  def crear(attrs = {})
    Tarifa.create!({ tipo_envio: @cer, precio_libra: 4.50, moneda: "USD" }.merge(attrs))
  end

  # ── Cobro básico ─────────────────────────────────────────────

  test "cobra peso por precio por libra" do
    t = crear(precio_libra: 4.50)

    r = t.cobro_para(10)

    assert_equal BigDecimal("45.00"), r[:subtotal]
    assert_equal "USD", r[:moneda]
    assert_not r[:aplico_minimo]
  end

  test "sin incremento no redondea el peso — preserva el comportamiento historico" do
    t = crear(precio_libra: 2.00, incremento_libras: nil)

    r = t.cobro_para(3.2)

    assert_equal BigDecimal("6.40"), r[:subtotal], "3.2 lb debe cobrarse como 3.2, no como 4"
    assert_equal BigDecimal("3.2"), r[:peso_facturado]
  end

  test "redondeo de montos es half-up al segundo decimal" do
    # `precio_libra` es numeric(10,2), así que el tercer decimal tiene que
    # salir del producto, no del precio.
    t = crear(precio_libra: 1.01)

    # 2.5 × 1.01 = 2.525 → half-up → 2.53 (no 2.52, que daría banker's rounding)
    assert_equal BigDecimal("2.53"), t.cobro_para(2.5)[:subtotal]
  end

  # ── Mínimo de monto ──────────────────────────────────────────

  test "aplica el minimo de monto cuando el calculo queda por debajo" do
    t = crear(precio_libra: 4.50, minimo_monto: 10.00, minimo_moneda: "USD")

    r = t.cobro_para(1) # 4.50 < 10.00

    assert_equal BigDecimal("10.00"), r[:subtotal]
    assert r[:aplico_minimo]
  end

  test "no aplica el minimo cuando el calculo lo supera" do
    t = crear(precio_libra: 4.50, minimo_monto: 10.00, minimo_moneda: "USD")

    r = t.cobro_para(10) # 45.00 > 10.00

    assert_equal BigDecimal("45.00"), r[:subtotal]
    assert_not r[:aplico_minimo]
  end

  test "el minimo en otra moneda se devuelve SIN convertir, para no perder centavos" do
    Configuracion.set("tasa_cambio", "25.0", tipo: "decimal")
    # Mínimo L.250 = $10 a tasa 25. Precio $4.50/lb → 4.50 < 10 → aplica.
    t = crear(precio_libra: 4.50, minimo_monto: 250.00, minimo_moneda: "LPS", moneda: "USD")

    r = t.cobro_para(1)

    assert_equal BigDecimal("250.00"), r[:subtotal]
    assert_equal "LPS", r[:moneda], "el caller convierte una sola vez, desde acá"
    assert r[:aplico_minimo]
  end

  test "aplica_minimo false ignora el minimo — el caso Exchange/Chain" do
    t = crear(precio_libra: 4.50, minimo_monto: 200.00, minimo_moneda: "LPS",
              aplica_minimo: false)

    r = t.cobro_para(0.5)

    assert_equal BigDecimal("2.25"), r[:subtotal]
    assert_not r[:aplico_minimo]
  end

  # ── Mínimo de libras ─────────────────────────────────────────

  test "aplica el minimo de libras — el caso CEM/CKM" do
    t = crear(tipo_envio: @cem, precio_libra: 1.50, minimo_libras: 20)

    r = t.cobro_para(2)

    assert_equal BigDecimal("20"), r[:peso_facturado]
    assert_equal BigDecimal("30.00"), r[:subtotal], "2 lb debe cobrarse como el minimo de 20"
  end

  test "el minimo de libras no baja un peso mayor" do
    t = crear(tipo_envio: @cem, precio_libra: 1.50, minimo_libras: 20)

    assert_equal BigDecimal("25"), t.cobro_para(25)[:peso_facturado]
  end

  # ── Incremento (media libra) ─────────────────────────────────

  test "incremento de media libra redondea hacia arriba" do
    t = crear(precio_libra: 4.00, incremento_libras: 0.5)

    assert_equal BigDecimal("0.5"), t.cobro_para(0.1)[:peso_facturado],
                 "una cosita chiquitita se cobra como media libra"
    assert_equal BigDecimal("0.5"), t.cobro_para(0.5)[:peso_facturado]
    assert_equal BigDecimal("1.0"), t.cobro_para(0.6)[:peso_facturado]
    assert_equal BigDecimal("2.5"), t.cobro_para(2.1)[:peso_facturado]
  end

  # ── Mínimo con ISV ───────────────────────────────────────────

  test "el minimo se guarda sin ISV y se lee con ISV" do
    # Yusef: "L.173.91 más ISV (queda en L.200.00 ya con ISV)"
    t = crear(minimo_moneda: "LPS")
    t.minimo_monto_con_isv = 200.00
    t.save!

    assert_equal BigDecimal("173.91"), t.reload.minimo_monto
    assert_equal BigDecimal("200.00"), t.minimo_monto_con_isv
  end

  # ── Cascada de resolución ────────────────────────────────────

  test "sin nada especifico devuelve la tarifa de lista" do
    lista = crear(precio_libra: 4.50)

    assert_equal lista, Tarifa.resolver(tipo_envio: @cer, peso: 5, cliente: @juan)
  end

  test "la categoria del cliente gana sobre la lista" do
    crear(precio_libra: 4.50)
    cat = crear(precio_libra: 3.50, categoria_precio: @juan.categoria_precio)

    assert_equal cat, Tarifa.resolver(tipo_envio: @cer, peso: 5, cliente: @juan)
  end

  test "el precio especial del cliente gana sobre su categoria" do
    crear(precio_libra: 4.50)
    crear(precio_libra: 3.50, categoria_precio: @juan.categoria_precio)
    especial = crear(precio_libra: 2.00, cliente: @juan)

    assert_equal especial, Tarifa.resolver(tipo_envio: @cer, peso: 5, cliente: @juan)
  end

  test "la promo del proveedor gana sobre la categoria pero no sobre el cliente" do
    crear(precio_libra: 4.50)
    crear(precio_libra: 3.50, categoria_precio: @juan.categoria_precio)
    promo = crear(precio_libra: 1.00, proveedor: proveedores(:Amazon))

    assert_equal promo, Tarifa.resolver(tipo_envio: @cer, peso: 5, cliente: @juan,
                                        proveedor: proveedores(:Amazon))

    especial = crear(precio_libra: 0.50, cliente: @juan)
    assert_equal especial, Tarifa.resolver(tipo_envio: @cer, peso: 5, cliente: @juan,
                                           proveedor: proveedores(:Amazon))
  end

  test "la tarifa de la sucursal gana sobre la generica del mismo nivel" do
    crear(precio_libra: 4.50)
    con_sucursal = crear(precio_libra: 5.00, sucursal: sucursales(:zeron_sps))

    assert_equal con_sucursal,
                 Tarifa.resolver(tipo_envio: @cer, peso: 5, sucursal: sucursales(:zeron_sps))
    assert_equal BigDecimal("4.50"),
                 Tarifa.resolver(tipo_envio: @cer, peso: 5).precio_libra
  end

  # ── Escalones ────────────────────────────────────────────────

  test "elige el escalon que contiene el peso" do
    bajo = crear(precio_libra: 5.00, desde_libras: 0, hasta_libras: 3)
    alto = crear(precio_libra: 3.00, desde_libras: 3, hasta_libras: nil)

    assert_equal bajo, Tarifa.resolver(tipo_envio: @cer, peso: 2)
    assert_equal alto, Tarifa.resolver(tipo_envio: @cer, peso: 3), "el limite es inclusivo abajo"
    assert_equal alto, Tarifa.resolver(tipo_envio: @cer, peso: 50)
  end

  test "ignora las tarifas inactivas" do
    crear(precio_libra: 4.50, activo: false)

    assert_nil Tarifa.resolver(tipo_envio: @cer, peso: 5)
  end

  # ── Validaciones ─────────────────────────────────────────────

  test "hasta debe ser mayor que desde" do
    t = Tarifa.new(tipo_envio: @cer, precio_libra: 1, moneda: "USD",
                   desde_libras: 5, hasta_libras: 3)

    assert_not t.valid?
    assert_includes t.errors[:hasta_libras], "debe ser mayor que 'desde'"
  end

  test "un monto minimo exige su moneda" do
    t = Tarifa.new(tipo_envio: @cer, precio_libra: 1, moneda: "USD", minimo_monto: 200)

    assert_not t.valid?
    assert_includes t.errors[:minimo_moneda], "es obligatoria cuando hay un monto mínimo"
  end
end
