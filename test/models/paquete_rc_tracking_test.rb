require "test_helper"

# PR-D4.d: paquetes con recolecta solicitada (CEC mandó motorista al
# comercio) reciben tracking auto-generado RC-AÑO-SUC-PROV-NNNNNN
# cuando el operador no escribe tracking propio.
class PaqueteRcTrackingTest < ActiveSupport::TestCase
  setup do
    @cliente   = clientes(:juan)
    @sucursal  = sucursales(:miami)              # codigo_ep = SMI
    @driver    = Proveedor.create!(nombre: "Driver test EP", tipo: "entrega_personal")
    @comercio  = proveedores(:Amazon)             # tipo: comercio (codigo: AMA)
  end

  def crear_paquete(**overrides)
    defaults = { cliente: @cliente, sucursal: @sucursal, tracking: nil }
    Paquete.create!(defaults.merge(overrides))
  end

  test "auto-genera tracking RC cuando recolecta_solicitada + proveedor comercio + tracking blank" do
    p = crear_paquete(proveedor: @comercio, recolecta_solicitada: true, recolecta_monto: 35)
    expected_year = Time.zone.now.year
    assert_match(/\ARC-#{expected_year}-SMI-#{@comercio.codigo}-\d{6}\z/, p.tracking)
  end

  test "respeta tracking del operador aunque haya recolecta_solicitada" do
    p = crear_paquete(proveedor: @comercio, recolecta_solicitada: true, recolecta_monto: 35,
                      tracking: "TRACKING-MANUAL-123")
    assert_equal "TRACKING-MANUAL-123", p.tracking
  end

  test "NO genera RC si no hay recolecta_solicitada" do
    p = crear_paquete(proveedor: @comercio, tracking: "1Z999AMAZON")
    assert_no_match(/\ARC-/, p.tracking)
  end

  test "EP gana sobre RC cuando proveedor es entrega_personal" do
    # Aunque recolecta_solicitada esté true, si el proveedor es EP
    # (driver externo), se genera tracking EP (no RC).
    p = crear_paquete(proveedor: @driver, recolecta_solicitada: true, recolecta_monto: 35)
    assert_match(/\AEP-/, p.tracking)
    assert_no_match(/\ARC-/, p.tracking)
  end

  test "correlativo RC incrementa entre creaciones secuenciales" do
    p1 = crear_paquete(proveedor: @comercio, recolecta_solicitada: true, recolecta_monto: 35)
    p2 = crear_paquete(proveedor: @comercio, recolecta_solicitada: true, recolecta_monto: 35)
    n1 = p1.tracking[/(\d{6})\z/, 1].to_i
    n2 = p2.tracking[/(\d{6})\z/, 1].to_i
    assert_equal n1 + 1, n2
  end

  test "RC y EP usan counters independientes (no chocan)" do
    # Crear EP con un proveedor entrega_personal
    ep = crear_paquete(proveedor: @driver, recolecta_solicitada: false)
    ep_n = ep.tracking[/(\d{6})\z/, 1].to_i

    # Crear RC con proveedor comercio — debe arrancar su propia secuencia
    rc = crear_paquete(proveedor: @comercio, recolecta_solicitada: true, recolecta_monto: 35)
    rc_n = rc.tracking[/(\d{6})\z/, 1].to_i

    # Ambos cuentan desde 1 cada uno (independientes, distintos proveedores)
    assert_equal 1, ep_n
    assert_equal 1, rc_n
  end
end
