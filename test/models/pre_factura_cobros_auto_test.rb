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
    # PR-M8: `build_from_paquetes` ahora filtra por `facturables`. Un paquete
    # recién creado nace en el arranque del pipeline y no lo es; estos tests
    # miran las líneas automáticas, no la puerta de entrada.
    defaults = { cliente: @cliente, sucursal: @sucursal, estado: "disponible_entrega",
                 tracking: "PR-D6B-#{SecureRandom.hex(4)}" }
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
    # PR-10.a: la tarifa de recolecta se carga en USD y el documento es en
    # Lempiras — antes el monto entraba crudo y se mostraba como "L. 35.00".
    assert_equal CurrencyAware.convertir(35.0, de: "USD", a: "LPS"), rec.subtotal.to_d
    assert_match(/Recolecta/, rec.concepto)
  end

  # PR-10.a: `precio_incluye_isv` se ignoraba, así que a un servicio con el
  # impuesto ya adentro se le volvía a aplicar el 15% al totalizar. Ahora la
  # línea lleva el neto y el ISV se suma una sola vez.
  test "agrega línea auto_servicio_extra cuando solicito_cambio_servicio" do
    p = crear_paquete(solicito_cambio_servicio: true)
    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ])
    serv = pf.pre_factura_items.find { |i| i.origen == "auto_servicio_extra" }
    assert serv
    esperado = CurrencyAware.convertir(@servicio.precio_venta_sin_isv, de: @servicio.moneda, a: "LPS")
    assert_equal esperado, serv.subtotal.to_d
    assert_equal @servicio.id, serv.servicio_extra_id
  end

  test "el servicio con ISV incluido termina cobrandose por su precio de lista" do
    assert @servicio.precio_incluye_isv?, "la fixture debe traer el ISV incluido"
    p = crear_paquete(solicito_cambio_servicio: true, peso: nil)
    pf = PreFactura.build_from_paquetes(@cliente, [ p.id ])
    serv = pf.pre_factura_items.find { |i| i.origen == "auto_servicio_extra" }

    # neto + 15%, de vuelta a la moneda del catálogo, debe devolver el precio
    # que Yusef cargó.
    con_isv = (serv.subtotal.to_d * (1 + IsvAware.rate)).round(2, BigDecimal::ROUND_HALF_UP)
    en_catalogo = CurrencyAware.convertir(con_isv, de: "LPS", a: @servicio.moneda)
    assert_in_delta @servicio.precio_venta.to_f, en_catalogo.to_f, 0.02
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
