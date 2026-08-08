require "test_helper"

# PR-C6.1: el cargo por cambio de servicio cobraba 3.7× de más, y salía solo.
#
# Yusef, 2026-08-08, recorriendo su hoja de precios:
#
#   "Es un ajuste que se le hace por hacer cambio de servicio que son los
#    **100 lempiras**. Yo te lo puse que eran 5."
#
# Estaba cargado en **$15 USD**. A la tasa vigente eso son ~L.324 netos, o sea
# **~L.373 con ISV** contra los L.100 que él dice. Y no es un cargo que alguien
# elige a mano: `PreFactura#aplicar_cobros_automaticos_para` lo agrega solo
# cuando el paquete trae `solicito_cambio_servicio`, y `facturar!` lo arrastra
# a una nota de débito que se crea sola.
#
# Los tests de `pre_factura_cobros_auto_test.rb` no lo agarraron porque
# comparan contra `@servicio.precio_venta` — prueban el mecanismo, no el
# número. Estos ponen el número.
class CambioServicioPrecioTest < ActiveSupport::TestCase
  setup do
    TarifasPropuesta2026.sembrar!
    @cliente = clientes(:juan)
    @user    = users(:cajero)

    ServicioExtra.find_or_create_by!(codigo: "CAMBIO_SERVICIO") do |s|
      s.descripcion = "Cambio de servicio"
      s.costo = 0
      s.precio_venta = 15.00      # el valor viejo, a propósito
      s.moneda = "USD"
      s.precio_incluye_isv = true
    end
    ServiciosExtraPropuesta2026.corregir_cambio_servicio!
  end

  test "la linea de la pre-factura cobra L.100 con ISV, no L.373" do
    paquete = paquete_con_cambio_de_servicio
    pf = PreFactura.build_from_paquetes(@cliente, [ paquete.id ], user: @user)

    linea = pf.pre_factura_items.find { |i| i.origen == "auto_servicio_extra" }
    assert linea, "el cargo tiene que generarse solo"

    # El neto entra a la línea; el ISV se suma una sola vez al totalizar.
    assert_equal BigDecimal("86.96"), linea.subtotal.to_d
    assert_equal BigDecimal("100.00"),
                 (linea.subtotal.to_d * (1 + IsvAware.rate)).round(2, BigDecimal::ROUND_HALF_UP)
  end

  test "el cargo sobrevive a facturar y la venta cobra L.100" do
    # La factura es el documento que efectivamente cobra. Ya pasó antes que un
    # monto correcto en la pre-factura se recalculara al facturar y saliera
    # distinto (el mínimo de servicio, PR-13.a), así que el número se verifica
    # también del otro lado.
    paquete = paquete_con_cambio_de_servicio
    pf = PreFactura.build_from_paquetes(@cliente, [ paquete.id ], user: @user)
    pf.save!
    venta = pf.facturar!

    # `VentaItem` no lleva `origen` ni `servicio_extra_id`: al facturar, la
    # línea auto queda identificada solo por su concepto.
    linea = venta.venta_items.find { |i| i.concepto.to_s.start_with?("Cambio de servicio") }
    assert linea, "el cargo tiene que sobrevivir a facturar"

    assert_equal BigDecimal("86.96"), linea.subtotal.to_d
    assert_equal BigDecimal("100.00"),
                 (linea.subtotal.to_d * (1 + IsvAware.rate)).round(2, BigDecimal::ROUND_HALF_UP)
  end

  # Ojo con lo que la nota de débito NO es. Al facturar un paquete con el flag,
  # `PreFactura#facturar!` crea una `NotaDebito` motivo "cambio_servicio" — pero
  # sus líneas son un **ajuste de flete**, no el cargo de los L.100. El cargo
  # vive en la pre-factura y en la venta, que es donde se cobra.
  #
  # Queda como test para que nadie lo asuma al revés y termine cobrando el
  # cambio de servicio dos veces.
  test "la nota de debito automatica no duplica el cargo" do
    paquete = paquete_con_cambio_de_servicio
    pf = PreFactura.build_from_paquetes(@cliente, [ paquete.id ], user: @user)
    pf.save!
    pf.facturar!

    nd = NotaDebito.order(:id).last
    assert nd, "facturar tiene que dejar la nota de débito creada"
    assert_equal "cambio_servicio", nd.motivo

    assert_empty nd.nota_debito_items.select { |i| i.concepto.to_s.match?(/cambio de servicio/i) },
                 "la nota de débito no debe traer el cargo: ya se cobró en la venta"
  end

  test "sin cambio de servicio no aparece la linea" do
    # El guard de que no se agregó un cargo a todo el mundo.
    paquete = paquete_con_cambio_de_servicio(solicito_cambio_servicio: false)
    pf = PreFactura.build_from_paquetes(@cliente, [ paquete.id ], user: @user)

    assert_nil pf.pre_factura_items.find { |i| i.origen == "auto_servicio_extra" }
  end

  private

  def paquete_con_cambio_de_servicio(solicito_cambio_servicio: true)
    @seq = (@seq || 0) + 1
    Paquete.create!(
      tracking: "CAMBSERV#{@seq}#{SecureRandom.hex(3)}",
      cliente: @cliente,
      tipo_envio: tipo_envios(:cer),
      sucursal: sucursales(:zeron_sps),
      estado: "disponible_entrega",
      peso: 10, peso_cobrar: 10,
      cantidad_productos: 1, cantidad_paquetes: 1,
      descripcion: "Paquete de prueba",
      solicito_cambio_servicio: solicito_cambio_servicio,
      user: users(:digitador)
    )
  end
end
