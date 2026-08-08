require "test_helper"

# PR-C6.12: los servicios extra necesitan mínimo, como en el sistema viejo.
#
# Yusef, 2026-08-08, mostrando el CRUD de Roger:
#
#   "Precio mínimo a cobrar, lo tiene **obligado**."
#
# Y hace falta de verdad — el retornado de Miami *es* un mínimo:
#
#   "Retornar a Miami dice 5 dólares, pero eso es como un precio mínimo que
#    cobramos, porque son 5 dólares MÁS el trámite más la llevada al correo."
#
# `Tarifa` ya tenía `minimo_monto` / `minimo_moneda`; `ServicioExtra` no tenía
# nada, así que un cargo por debajo del piso se cobraba de menos.
class ServicioExtraMinimoTest < ActiveSupport::TestCase
  test "sin minimo se cobra el precio tal cual" do
    s = servicio(precio: 10, minimo: nil)

    assert_not s.aplica_minimo?
    assert_equal BigDecimal("10.00"), s.cobro_para(1, en: "USD")
  end

  test "cuando el cobro cae bajo el piso, se cobra el piso" do
    s = servicio(precio: 2, minimo: 5, incluye_isv: false)

    assert_equal BigDecimal("5.00"), s.cobro_para(1, en: "USD")
  end

  test "cuando el cobro supera el piso, manda el cobro" do
    s = servicio(precio: 8, minimo: 5, incluye_isv: false)

    assert_equal BigDecimal("8.00"), s.cobro_para(1, en: "USD")
  end

  test "el piso aplica sobre el total, no sobre la unidad" do
    # 3 unidades × $2 = $6, que ya pasa el piso de $5.
    s = servicio(precio: 2, minimo: 5, incluye_isv: false)

    assert_equal BigDecimal("6.00"), s.cobro_para(3, en: "USD")
  end

  test "el minimo puede estar en otra moneda que el precio" do
    # Es el caso que Yusef describió para el flete: se cotiza en dólares y el
    # piso vive en Lempiras, porque así lo pone la competencia.
    s = servicio(precio: 1, minimo: 200, incluye_isv: false)
    s.update!(moneda: "USD", minimo_moneda: "LPS")

    # $1 ≈ L.24.85, muy por debajo de L.200 → se cobra el piso.
    assert_equal BigDecimal("200.00"), s.cobro_para(1, en: "LPS")
  end

  test "el minimo se compara sin ISV cuando el precio lo trae adentro" do
    # Yusef habla del mínimo como precio final. Si se comparara el bruto
    # contra un subtotal neto, el piso quedaría 15% más alto de lo que él dijo.
    s = servicio(precio: 100, minimo: 100, incluye_isv: true)
    s.update!(moneda: "LPS")   # el cargo y el piso en la misma moneda

    neto = s.cobro_para(1, en: "LPS")
    assert_equal BigDecimal("86.96"), neto
    assert_equal BigDecimal("100.00"),
                 (neto * (1 + IsvAware.rate)).round(2, BigDecimal::ROUND_HALF_UP)
  end

  test "el minimo en cero es lo mismo que sin minimo" do
    s = servicio(precio: 3, minimo: 0)

    assert_not s.aplica_minimo?
    assert_equal BigDecimal("3.00"), s.cobro_para(1, en: "USD")
  end

  test "una moneda invalida en el minimo no pasa" do
    s = servicio(precio: 3, minimo: 5)
    s.minimo_moneda = "EUR"

    assert_not s.valid?
  end

  # ── Lo que no se puede romper ──────────────────────────────────────────

  test "la linea automatica de la pre-factura respeta el piso" do
    # El camino real: `aplicar_cobros_automaticos_para` construye la línea.
    TarifasPropuesta2026.sembrar!
    servicio_cambio = ServicioExtra.find_or_create_by!(codigo: "CAMBIO_SERVICIO") do |s|
      s.descripcion = "Cambio de servicio"
      s.costo = 0
      s.precio_venta = 1
      s.moneda = "USD"
    end
    servicio_cambio.update!(precio_venta: 1, moneda: "USD", precio_incluye_isv: false,
                            minimo_monto: 500, minimo_moneda: "LPS")

    cliente = clientes(:juan)
    paquete = Paquete.create!(
      tracking: "MIN#{SecureRandom.hex(4)}", cliente: cliente,
      tipo_envio: tipo_envios(:cer), sucursal: sucursales(:zeron_sps),
      estado: "disponible_entrega", peso: 10, peso_cobrar: 10,
      cantidad_productos: 1, cantidad_paquetes: 1, descripcion: "x",
      solicito_cambio_servicio: true, user: users(:digitador)
    )

    pf = PreFactura.build_from_paquetes(cliente, [ paquete.id ], user: users(:cajero))
    linea = pf.pre_factura_items.find { |i| i.origen == "auto_servicio_extra" }

    assert_equal BigDecimal("500.00"), linea.subtotal.to_d,
                 "el cargo se cobró por debajo de su mínimo"
  end

  private

  def servicio(precio:, minimo:, incluye_isv: false)
    ServicioExtra.create!(
      codigo: "TEST_#{SecureRandom.hex(3).upcase}",
      descripcion: "Servicio de prueba",
      costo: 0,
      precio_venta: precio,
      moneda: "USD",
      precio_incluye_isv: incluye_isv,
      minimo_monto: minimo,
      activo: true
    )
  end
end
