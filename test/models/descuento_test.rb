require "test_helper"

# PR-13.b: el descuento como dato propio.
#
# Hasta acá un descuento se hacía bajándole el precio a la línea, así que era
# invisible: la factura salía con un precio más bajo y nada decía que hubo
# descuento, ni de cuánto, ni quién lo dio. Yusef va a autorizar descuentos con
# su PIN, y mal se puede autorizar algo que después no queda registrado.
class DescuentoTest < ActiveSupport::TestCase
  setup do
    TarifasPropuesta2026.sembrar!
    @cliente = clientes(:juan)
    @user = users(:cajero)
  end

  # ── Lo que no se puede romper ───────────────────────────────────────────

  test "sin descuento los totales dan exactamente lo mismo que antes" do
    # El riesgo real de tocar `calculate_totals`: que se mueva la plata de las
    # pre-facturas que ya existen.
    pf = pre_facturas(:borrador_juan)
    subtotal_previo = pf.subtotal
    impuesto_previo = pf.impuesto
    total_previo    = pf.total

    pf.save!

    assert_equal subtotal_previo, pf.reload.subtotal
    assert_equal impuesto_previo, pf.impuesto
    assert_equal total_previo, pf.total
    assert_equal 0, pf.descuento
  end

  # ── La regla que confirmó Jorge: ISV sobre el neto ──────────────────────

  test "el ISV se calcula sobre el subtotal menos el descuento" do
    pf = pre_factura_con(peso: 10)                # 10 lb CER → L.1,118.30
    item = pf.pre_factura_items.first
    assert_equal BigDecimal("1118.30"), item.subtotal

    item.aplicar_descuento_porcentaje(10)
    pf.save!

    assert_equal BigDecimal("111.83"), item.descuento_monto
    assert_equal BigDecimal("1118.30"), pf.subtotal, "el subtotal sigue siendo el bruto"
    assert_equal BigDecimal("111.83"),  pf.descuento

    # Base gravada 1,006.47 × 15% = 150.9705 → 150.97 half-up
    assert_equal BigDecimal("150.97"),  pf.impuesto
    assert_equal BigDecimal("1157.44"), pf.total

    # Y el ISV sobre el bruto habría dado 167.75: 16.78 de más al cliente.
    assert_operator pf.impuesto, :<, (pf.subtotal.to_d * IsvAware.rate)
  end

  test "el descuento por monto fijo no guarda porcentaje" do
    pf = pre_factura_con(peso: 10)
    item = pf.pre_factura_items.first

    item.aplicar_descuento_monto(200)
    pf.save!

    assert_equal BigDecimal("200.00"), pf.reload.descuento
    assert_nil item.reload.descuento_porcentaje
    assert_equal "200.00", item.descuento_label
  end

  test "el porcentaje queda de constancia para poder imprimirlo" do
    pf = pre_factura_con(peso: 10)
    item = pf.pre_factura_items.first

    item.aplicar_descuento_porcentaje(10)
    pf.save!

    assert_equal "10%", item.reload.descuento_label
  end

  # ── Que no se pierda por el camino ──────────────────────────────────────

  test "el descuento sobrevive a facturar" do
    pf = pre_factura_con(peso: 10)
    pf.pre_factura_items.first.aplicar_descuento_porcentaje(10)
    pf.save!

    venta = pf.facturar!
    item = venta.venta_items.first

    assert_equal BigDecimal("111.83"), item.descuento_monto
    assert_equal BigDecimal("10.0"),   item.descuento_porcentaje
    assert_equal BigDecimal("111.83"), venta.descuento
    assert_equal pf.total, venta.total, "la venta cobra distinto que la pre-factura"
  end

  test "el saldo del cliente refleja el total con descuento" do
    pf = pre_factura_con(peso: 10)
    pf.pre_factura_items.first.aplicar_descuento_porcentaje(10)
    pf.save!

    saldo_previo = @cliente.reload.saldo_pendiente.to_d
    venta = pf.facturar!

    assert_equal saldo_previo + venta.total.to_d, @cliente.reload.saldo_pendiente.to_d
  end

  # ── Los bordes ──────────────────────────────────────────────────────────

  test "el descuento no puede superar el subtotal de la linea" do
    pf = pre_factura_con(peso: 10)
    item = pf.pre_factura_items.first

    item.aplicar_descuento_monto(item.subtotal.to_d + 1)

    assert_not pf.valid?
    assert_includes pf.errors.full_messages.join(" "), "mayor que el subtotal"
  end

  test "un descuento del 100 por ciento deja la linea en cero, no en negativo" do
    pf = pre_factura_con(peso: 10)
    item = pf.pre_factura_items.first

    item.aplicar_descuento_porcentaje(100)
    pf.save!

    assert_equal BigDecimal("0"), item.total_linea
    assert_equal BigDecimal("0"), pf.impuesto
    assert_equal BigDecimal("0"), pf.total
  end

  test "el descuento no se recalcula solo si despues cambia el subtotal" do
    # Un descuento que se mueve después de que un supervisor lo autorizó deja
    # de ser lo que se autorizó.
    pf = pre_factura_con(peso: 10)
    item = pf.pre_factura_items.first
    item.aplicar_descuento_porcentaje(10)
    pf.save!

    item.update!(peso_cobrar: 20)   # el subtotal se duplica

    assert_equal BigDecimal("111.83"), item.reload.descuento_monto,
                 "el descuento autorizado no debe seguir al subtotal"
  end

  private

  def pre_factura_con(peso:)
    @seq = (@seq || 0) + 1
    paquete = Paquete.create!(
      tracking: "DESC#{@seq}#{peso}",
      cliente: @cliente,
      tipo_envio: tipo_envios(:cer),
      sucursal: sucursales(:zeron_sps),
      estado: "disponible_entrega",
      peso: peso, peso_cobrar: peso,
      cantidad_productos: 1, cantidad_paquetes: 1,
      descripcion: "Paquete de prueba",
      user: users(:digitador)
    )
    PreFactura.build_from_paquetes(@cliente, [ paquete.id ], user: @user).tap(&:save!)
  end
end
