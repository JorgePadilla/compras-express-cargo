require "test_helper"

class NotaDebitoTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
    @venta = ventas(:pendiente_juan)
    @user = users(:cajero)
  end

  test "auto-generates numero on create" do
    nd = NotaDebito.new(venta: @venta, cliente: @cliente, motivo: "ajuste_manual")
    nd.nota_debito_items.build(concepto: "Test", subtotal: 10)
    nd.save!
    assert_match(/\AND-\d{6}\z/, nd.numero)
  end

  test "default estado is creado" do
    nd = NotaDebito.new(venta: @venta, cliente: @cliente, motivo: "ajuste_manual")
    assert_equal "creado", nd.estado
  end

  test "calculate_totals applies ISV" do
    nd = NotaDebito.new(venta: @venta, cliente: @cliente, motivo: "ajuste_manual")
    nd.nota_debito_items.build(concepto: "Test", subtotal: 100)
    nd.save!
    assert_equal 100.to_d, nd.subtotal.to_d
    assert_equal 15.to_d, nd.impuesto.to_d
    assert_equal 115.to_d, nd.total.to_d
  end

  test "emitir! transitions to emitido and increments saldo" do
    nd = notas_debito(:nd_creada)
    initial_saldo = nd.cliente.saldo_pendiente.to_d
    nd.emitir!
    assert_equal "emitido", nd.estado
    assert_not_nil nd.emitido_at
    nd.cliente.reload
    assert_equal initial_saldo + nd.total.to_d, nd.cliente.saldo_pendiente.to_d
  end

  test "emitir! fails when not creado" do
    nd = notas_debito(:nd_emitida)
    assert_not nd.emitir!
  end

  test "anular! transitions from emitido and decrements saldo" do
    nd = notas_debito(:nd_emitida)
    initial_saldo = nd.cliente.saldo_pendiente.to_d
    nd.anular!
    assert_equal "anulado", nd.estado
    assert_not_nil nd.anulado_at
    nd.cliente.reload
    assert_equal [initial_saldo - nd.total.to_d, 0].max.to_d, nd.cliente.saldo_pendiente.to_d
  end

  test "anular! fails when not emitido" do
    nd = notas_debito(:nd_creada)
    assert_not nd.anular!
  end

  test "scopes work correctly" do
    assert_includes NotaDebito.creadas, notas_debito(:nd_creada)
    assert_includes NotaDebito.emitidas, notas_debito(:nd_emitida)
    assert_includes NotaDebito.anuladas, notas_debito(:nd_anulada)
  end

  test "motivo validation" do
    nd = NotaDebito.new(venta: @venta, cliente: @cliente, estado: "creado")
    nd.motivo = "invalid"
    assert_not nd.valid?
    assert nd.errors[:motivo].any?
  end

  test "build_from_paquetes creates nd with items" do
    paquete = paquetes(:disponible_entrega_juan)
    nd = NotaDebito.build_from_paquetes(
      @venta,
      paquete_ids: [paquete.id],
      motivo: "cambio_servicio",
      user: @user
    )
    assert_equal "cambio_servicio", nd.motivo
    assert_equal @venta, nd.venta
    assert_equal @venta.cliente, nd.cliente
    assert nd.nota_debito_items.any?
  end
end
