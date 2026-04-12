require "test_helper"

class VentaTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
    @user = users(:cajero)
  end

  test "auto-generates numero on create" do
    v = Venta.create!(cliente: @cliente)
    assert_match /\AVT-\d{6}\z/, v.numero
  end

  test "requires unique numero" do
    Venta.create!(numero: "VT-999999", cliente: @cliente)
    dup = Venta.new(numero: "VT-999999", cliente: @cliente)
    assert_not dup.valid?
  end

  test "default estado is pendiente" do
    v = Venta.new(cliente: @cliente, estado: "pendiente")
    assert_equal "pendiente", v.estado
  end

  test "calculate_totals applies 15% ISV and sets saldo_pendiente on new record" do
    v = Venta.new(cliente: @cliente, estado: "pendiente")
    v.venta_items.build(concepto: "Flete", peso_cobrar: 10, precio_libra: 5, subtotal: 50)
    v.save!
    assert_equal 50.to_d, v.subtotal.to_d
    assert_equal "7.50".to_d, v.impuesto.to_d
    assert_equal "57.50".to_d, v.total.to_d
    assert_equal "57.50".to_d, v.saldo_pendiente.to_d
  end

  test "registrar_pago creates pago and recibo for full amount" do
    venta = ventas(:pendiente_juan)
    initial_cliente_saldo = venta.cliente.saldo_pendiente.to_d

    assert_difference ["Pago.count", "Recibo.count"], 1 do
      recibo = venta.registrar_pago(monto: venta.total, metodo_pago: "efectivo", user: @user)
      assert_kind_of Recibo, recibo
    end

    venta.reload
    assert venta.pagada?
    assert_equal 0, venta.saldo_pendiente.to_d
    assert_not_nil venta.pagada_at

    venta.cliente.reload
    assert_equal initial_cliente_saldo - venta.total.to_d, venta.cliente.saldo_pendiente.to_d
  end

  test "registrar_pago with partial amount keeps estado pendiente" do
    venta = ventas(:pendiente_juan)
    half = (venta.total.to_d / 2).round(2)

    venta.registrar_pago(monto: half, metodo_pago: "efectivo", user: @user)

    venta.reload
    assert venta.pendiente?
    assert_equal (venta.total.to_d - half).round(2), venta.saldo_pendiente.to_d
  end

  test "two partial pagos transition to pagada" do
    venta = ventas(:pendiente_juan)
    half = (venta.total.to_d / 2).round(2)

    venta.registrar_pago(monto: half, metodo_pago: "efectivo", user: @user)
    venta.registrar_pago(monto: venta.reload.saldo_pendiente, metodo_pago: "efectivo", user: @user)

    assert venta.reload.pagada?
    assert_equal 2, venta.pagos.count
    assert_equal 2, venta.recibos.count
  end

  test "registrar_pago returns nil when venta already pagada" do
    venta = ventas(:pagada_maria)
    assert_nil venta.registrar_pago(monto: 10, metodo_pago: "efectivo", user: @user)
  end

  test "registrar_pago returns nil for zero or negative amount" do
    venta = ventas(:pendiente_juan)
    assert_nil venta.registrar_pago(monto: 0, metodo_pago: "efectivo", user: @user)
    assert_nil venta.registrar_pago(monto: -5, metodo_pago: "efectivo", user: @user)
  end

  test "anular! refuses when pagada" do
    assert_not ventas(:pagada_maria).anular!
  end

  test "anular! releases paquetes when allowed" do
    venta = ventas(:pendiente_juan)
    # Link a paquete to the venta via venta_item so venta.paquetes includes it
    paquete = paquetes(:disponible_entrega_juan)
    venta_items(:pendiente_juan_item1).update!(paquete: paquete)
    paquete.update!(venta: venta)

    initial_cliente_saldo = @cliente.saldo_pendiente.to_d
    assert venta.anular!
    assert venta.anulada?

    paquete.reload
    assert_nil paquete.venta_id
    assert_equal "disponible_entrega", paquete.estado

    @cliente.reload
    assert_equal initial_cliente_saldo - venta.total.to_d, @cliente.saldo_pendiente.to_d
  end

  test "scope activas excludes anulada" do
    v = ventas(:pendiente_juan)
    v.update!(estado: "anulada")
    assert_not_includes Venta.activas, v
  end

  test "scope pagadas" do
    assert_includes Venta.pagadas, ventas(:pagada_maria)
    assert_not_includes Venta.pagadas, ventas(:pendiente_juan)
  end

  test "total_ajustado includes emitidas NDs and NCs" do
    venta = ventas(:pagada_maria)
    nd = notas_debito(:nd_emitida)  # total 23.00, emitida, belongs to pagada_maria
    nc = notas_credito(:nc_emitida) # total 13.80, emitida, belongs to pagada_maria

    expected = venta.total.to_d + nd.total.to_d - nc.total.to_d
    assert_equal expected, venta.total_ajustado.to_d
  end

  test "has_many notas_debito and notas_credito" do
    venta = ventas(:pagada_maria)
    assert_includes venta.notas_debito, notas_debito(:nd_emitida)
    assert_includes venta.notas_credito, notas_credito(:nc_emitida)
  end
end
