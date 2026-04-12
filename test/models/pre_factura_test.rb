require "test_helper"

class PreFacturaTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
    @user = users(:cajero)
  end

  test "auto-generates numero on create" do
    pf = PreFactura.create!(cliente: @cliente)
    assert_match /\APF-\d{6}\z/, pf.numero
  end

  test "requires unique numero" do
    PreFactura.create!(numero: "PF-999999", cliente: @cliente)
    dup = PreFactura.new(numero: "PF-999999", cliente: @cliente)
    assert_not dup.valid?
  end

  test "default estado is creado" do
    pf = PreFactura.new(cliente: @cliente)
    assert_equal "creado", pf.estado
  end

  test "estado must be in ESTADOS" do
    pf = PreFactura.new(cliente: @cliente, estado: "invalido")
    assert_not pf.valid?
    assert pf.errors[:estado].any?
  end

  test "calculate_totals applies 15% ISV" do
    pf = PreFactura.new(cliente: @cliente)
    pf.pre_factura_items.build(concepto: "Test", peso_cobrar: 10, precio_libra: 5, subtotal: 50)
    pf.save!
    assert_equal 50.to_d, pf.subtotal.to_d
    assert_equal "7.50".to_d, pf.impuesto.to_d
    assert_equal "57.50".to_d, pf.total.to_d
  end

  test "calculate_totals with multiple items" do
    pf = PreFactura.new(cliente: @cliente)
    pf.pre_factura_items.build(concepto: "A", subtotal: 100)
    pf.pre_factura_items.build(concepto: "B", subtotal: 50)
    pf.save!
    assert_equal 150.to_d, pf.subtotal.to_d
    assert_equal "22.50".to_d, pf.impuesto.to_d
    assert_equal "172.50".to_d, pf.total.to_d
  end

  test "confirmar! transitions creado to pendiente" do
    pf = pre_facturas(:borrador_juan)
    assert pf.confirmar!
    assert pf.pendiente?
    assert_not_nil pf.confirmado_at
  end

  test "confirmar! returns false when not creado" do
    pf = pre_facturas(:pendiente_maria)
    assert_not pf.confirmar!
  end

  test "facturar! creates Venta and updates paquetes" do
    paquete = paquetes(:disponible_entrega_juan)
    pf = PreFactura.build_from_paquetes(@cliente, [paquete.id], user: @user)
    pf.save!
    venta = pf.facturar!

    assert_kind_of Venta, venta
    assert_equal @cliente, venta.cliente
    assert_equal pf, venta.pre_factura
    assert_equal pf.total, venta.total
    assert_equal 1, venta.venta_items.count

    paquete.reload
    assert_equal venta.id, paquete.venta_id

    assert pf.reload.facturado?
    assert_not_nil pf.facturado_at
  end

  test "facturar! increments cliente saldo_pendiente" do
    paquete = paquetes(:disponible_entrega_juan)
    initial_saldo = @cliente.saldo_pendiente.to_d
    pf = PreFactura.build_from_paquetes(@cliente, [paquete.id], user: @user)
    pf.save!
    venta = pf.facturar!

    @cliente.reload
    assert_equal initial_saldo + venta.total.to_d, @cliente.saldo_pendiente.to_d
  end

  test "facturar! returns false when already facturado" do
    pf = pre_facturas(:borrador_juan)
    pf.update!(estado: "facturado")
    assert_not pf.facturar!
  end

  test "anular! releases paquetes and sets estado anulado" do
    paquete = paquetes(:disponible_entrega_juan)
    pf = PreFactura.build_from_paquetes(@cliente, [paquete.id], user: @user)
    pf.save!
    pf.confirmar!

    assert pf.anular!
    assert pf.anulado?
    paquete.reload
    assert_nil paquete.pre_factura_id
    assert_equal "disponible_entrega", paquete.estado
  end

  test "anular! refuses after facturar" do
    pf = pre_facturas(:borrador_juan)
    pf.update!(estado: "facturado")
    assert_not pf.anular!
  end

  test "build_from_paquetes uses cliente categoria_precio" do
    paquete = paquetes(:disponible_entrega_juan)
    # juan has categoria regular: aereo=3.50
    pf = PreFactura.build_from_paquetes(@cliente, [paquete.id], user: @user)
    assert_equal 1, pf.pre_factura_items.size
    item = pf.pre_factura_items.first
    assert_equal "3.5".to_d, item.precio_libra.to_d
    # peso_cobrar = 10 (from fixture), subtotal = 35.00
    assert_equal "35.00".to_d, item.subtotal.to_d
  end

  test "build_from_paquetes falls back to tipo_envio precio" do
    # Remove categoria_precio so fallback is used
    @cliente.update!(categoria_precio: nil)
    paquete = paquetes(:disponible_entrega_juan)
    pf = PreFactura.build_from_paquetes(@cliente, [paquete.id], user: @user)
    item = pf.pre_factura_items.first
    # tipo_envios(:aereo).precio_libra = 4.50
    assert_equal "4.5".to_d, item.precio_libra.to_d
  end

  test "scope activas excludes anulado" do
    anulada = pre_facturas(:borrador_juan)
    anulada.update!(estado: "anulado")
    assert_not_includes PreFactura.activas, anulada
  end

  test "scope pendientes" do
    assert_includes PreFactura.pendientes, pre_facturas(:pendiente_maria)
    assert_not_includes PreFactura.pendientes, pre_facturas(:borrador_juan)
  end

  test "scope by_cliente" do
    assert_includes PreFactura.by_cliente(@cliente.id), pre_facturas(:borrador_juan)
    assert_not_includes PreFactura.by_cliente(@cliente.id), pre_facturas(:pendiente_maria)
  end

  test "scope buscar by numero" do
    assert_includes PreFactura.buscar("PF-000001"), pre_facturas(:borrador_juan)
  end
end
