require "test_helper"

# PR-D3.b: paquetes ENTREGA PERSONAL reciben tracking auto-generado
# con formato EP-AÑO-SUC-PROV-NNNNNN cuando el operador no escribe
# tracking propio.
class PaqueteEpTrackingTest < ActiveSupport::TestCase
  setup do
    @cliente   = clientes(:juan)
    @sucursal  = sucursales(:miami)               # codigo_ep = SMI
    @driver    = Proveedor.create!(nombre: "EpTest Driver Tres", tipo: "entrega_personal")
    @comercio  = proveedores(:Amazon)             # tipo: comercio (codigo: AMA)
  end

  test "auto-genera tracking EP cuando proveedor.entrega_personal? y tracking blank" do
    p = Paquete.create!(cliente: @cliente, sucursal: @sucursal, proveedor: @driver, tracking: nil)
    expected_year = Time.zone.now.year
    assert_match(/\AEP-#{expected_year}-SMI-#{@driver.codigo}-\d{6}\z/, p.tracking)
  end

  test "respeta tracking del operador aunque proveedor sea entrega_personal" do
    p = Paquete.create!(cliente: @cliente, sucursal: @sucursal, proveedor: @driver,
                        tracking: "UBER-DRIVER-XYZ-123")
    assert_equal "UBER-DRIVER-XYZ-123", p.tracking
  end

  test "NO genera EP cuando proveedor es comercio" do
    p = Paquete.create!(cliente: @cliente, sucursal: @sucursal, proveedor: @comercio,
                        tracking: "1Z999AMAZON")
    assert_equal "1Z999AMAZON", p.tracking
    assert_no_match(/\AEP-/, p.tracking)
  end

  test "NO genera EP cuando no hay proveedor (tracking blank → presence error)" do
    p = Paquete.new(cliente: @cliente, sucursal: @sucursal, proveedor: nil, tracking: nil)
    assert_not p.valid?
    assert p.errors[:tracking].any?
  end

  test "correlativo incrementa entre creaciones secuenciales" do
    p1 = Paquete.create!(cliente: @cliente, sucursal: @sucursal, proveedor: @driver, tracking: nil)
    p2 = Paquete.create!(cliente: @cliente, sucursal: @sucursal, proveedor: @driver, tracking: nil)
    n1 = p1.tracking[/(\d{6})\z/, 1].to_i
    n2 = p2.tracking[/(\d{6})\z/, 1].to_i
    assert_equal n1 + 1, n2
  end

  test "falla limpio si la sucursal no tiene codigo_ep" do
    @sucursal.update_column(:codigo_ep, nil)
    p = Paquete.new(cliente: @cliente, sucursal: @sucursal, proveedor: @driver, tracking: nil)
    assert_not p.valid?
    assert p.errors[:tracking].any?
  end

  test "el correlativo es independiente entre proveedores EP distintos" do
    otro_driver = Proveedor.create!(nombre: "EpTest Driver Cuatro", tipo: "entrega_personal")
    p1 = Paquete.create!(cliente: @cliente, sucursal: @sucursal, proveedor: @driver, tracking: nil)
    p2 = Paquete.create!(cliente: @cliente, sucursal: @sucursal, proveedor: otro_driver, tracking: nil)
    n1 = p1.tracking[/(\d{6})\z/, 1].to_i
    n2 = p2.tracking[/(\d{6})\z/, 1].to_i
    assert_equal 1, n1
    assert_equal 1, n2
  end
end
