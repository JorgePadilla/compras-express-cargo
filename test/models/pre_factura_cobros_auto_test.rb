require "test_helper"

# PR-D6.b: cuando un paquete entra a una pre-factura, los flags de
# recolecta y cambio de servicio se materializan como líneas auto.
class PreFacturaCobrosAutoTest < ActiveSupport::TestCase
  setup do
    @cliente   = clientes(:juan)
    @sucursal  = sucursales(:miami)
    @servicio  = ServicioExtra.find_or_create_by!(codigo: "CAMBIO_SERVICIO") do |s|
      s.descripcion = "Cambio de servicio"
      s.precio_venta = 15
      s.moneda = "USD"
      s.costo = 0
    end
  end

  def crear_paquete(**overrides)
    defaults = { cliente: @cliente, sucursal: @sucursal, tracking: "PR-D6B-#{SecureRandom.hex(4)}" }
    Paquete.create!(defaults.merge(overrides))
  end

  test "no agrega líneas auto si paquete no tiene flags" do
    p = crear_paquete
    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ])
    auto_count = pf.pre_factura_items.count { |i| i.origen != "manual" }
    assert_equal 0, auto_count
  end

  test "agrega línea auto_recolecta cuando recolecta_solicitada" do
    p = crear_paquete(recolecta_solicitada: true, recolecta_monto: 35.0, recolecta_moneda: "USD")
    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ])
    rec = pf.pre_factura_items.find { |i| i.origen == "auto_recolecta" }
    assert rec, "debe haber una línea auto_recolecta"
    assert_equal 35.0.to_d, rec.subtotal.to_d
    assert_match(/Recolecta/, rec.concepto)
  end

  test "agrega línea auto_servicio_extra cuando solicito_cambio_servicio" do
    p = crear_paquete(solicito_cambio_servicio: true)
    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ])
    serv = pf.pre_factura_items.find { |i| i.origen == "auto_servicio_extra" }
    assert serv
    assert_equal @servicio.precio_venta.to_d, serv.subtotal.to_d
    assert_equal @servicio.id, serv.servicio_extra_id
  end

  test "ambos flags activos generan dos líneas auto distintas" do
    p = crear_paquete(recolecta_solicitada: true, recolecta_monto: 50, solicito_cambio_servicio: true)
    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ])
    auto_origenes = pf.pre_factura_items.select(&:auto?).map(&:origen).sort
    assert_equal %w[auto_recolecta auto_servicio_extra], auto_origenes
  end

  test "no duplica línea auto_recolecta al re-aplicar al mismo paquete" do
    p = crear_paquete(recolecta_solicitada: true, recolecta_monto: 35)
    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ])
    pf.aplicar_cobros_automaticos_para(p)
    pf.aplicar_cobros_automaticos_para(p)
    rec_count = pf.pre_factura_items.count { |i| i.origen == "auto_recolecta" }
    assert_equal 1, rec_count
  end

  test "PreFacturaItem#auto? identifica correctamente" do
    auto = PreFacturaItem.new(origen: "auto_recolecta")
    manual = PreFacturaItem.new(origen: "manual")
    assert auto.auto?
    assert_not manual.auto?
  end

  test "scope auto/manual filtran correctamente" do
    p = crear_paquete(recolecta_solicitada: true, recolecta_monto: 30)
    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ])
    pf.save!
    pf.reload
    assert_equal 1, pf.pre_factura_items.auto.count
    assert_equal 1, pf.pre_factura_items.manual.count
  end
end
