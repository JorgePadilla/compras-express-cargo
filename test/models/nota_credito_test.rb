require "test_helper"

class NotaCreditoTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
    @venta = ventas(:pendiente_juan)
    @user = users(:cajero)
  end

  test "auto-generates numero on create" do
    nc = NotaCredito.new(venta: @venta, cliente: @cliente, motivo: "descuento")
    nc.nota_credito_items.build(concepto: "Test", subtotal: 10)
    nc.save!
    assert_match(/\ANC-\d{6}\z/, nc.numero)
  end

  test "default estado is creado" do
    nc = NotaCredito.new(venta: @venta, cliente: @cliente, motivo: "descuento")
    assert_equal "creado", nc.estado
  end

  test "calculate_totals applies ISV" do
    nc = NotaCredito.new(venta: @venta, cliente: @cliente, motivo: "descuento")
    nc.nota_credito_items.build(concepto: "Test", subtotal: 100)
    nc.save!
    assert_equal 100.to_d, nc.subtotal.to_d
    assert_equal 15.to_d, nc.impuesto.to_d
    assert_equal 115.to_d, nc.total.to_d
  end

  test "emitir! transitions to emitido and decrements saldo" do
    nc = notas_credito(:nc_creada)
    initial_saldo = nc.cliente.saldo_pendiente.to_d
    nc.emitir!
    assert_equal "emitido", nc.estado
    assert_not_nil nc.emitido_at
    nc.cliente.reload
    assert_equal [initial_saldo - nc.total.to_d, 0].max.to_d, nc.cliente.saldo_pendiente.to_d
  end

  test "emitir! fails when not creado" do
    nc = notas_credito(:nc_emitida)
    assert_not nc.emitir!
  end

  test "anular! transitions from emitido and increments saldo" do
    nc = notas_credito(:nc_emitida)
    initial_saldo = nc.cliente.saldo_pendiente.to_d
    nc.anular!
    assert_equal "anulado", nc.estado
    assert_not_nil nc.anulado_at
    nc.cliente.reload
    assert_equal initial_saldo + nc.total.to_d, nc.cliente.saldo_pendiente.to_d
  end

  test "anular! fails when not emitido" do
    nc = notas_credito(:nc_creada)
    assert_not nc.anular!
  end

  test "scopes work correctly" do
    assert_includes NotaCredito.creadas, notas_credito(:nc_creada)
    assert_includes NotaCredito.emitidas, notas_credito(:nc_emitida)
    assert_includes NotaCredito.anuladas, notas_credito(:nc_anulada)
  end

  test "motivo validation" do
    nc = NotaCredito.new(venta: @venta, cliente: @cliente, estado: "creado")
    nc.motivo = "invalid"
    assert_not nc.valid?
    assert nc.errors[:motivo].any?
  end
end
