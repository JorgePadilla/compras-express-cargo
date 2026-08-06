require "test_helper"

# PR-13.a: una nota de crédito o de débito por un paquete tiene que hablar de
# la misma plata que la venta le cobró a ese paquete.
#
# Las dos armaban sus líneas con la cadena que PR-10.a vino a reemplazar: sin
# mínimos, sin escalones y sin convertir a Lempiras, pero el documento se
# imprime en Lempiras. Mientras las tarifas eran un backfill plano casi no se
# notaba; con los precios reales de Yusef (PR-10.g) un CER de 10 lb del cliente
# Regular se factura a L.1,118.30 y la nota acreditaba L.35.00.
#
# Y la de débito **se auto-genera** al facturar un paquete con
# `solicito_cambio_servicio`, así que el error salía solo.
#
# Los tests comparan contra la `Venta`, no contra números escritos a mano: la
# invariante es que coincidan, no que valgan tal cosa.
class NotasPrecioRealTest < ActiveSupport::TestCase
  setup do
    TarifasPropuesta2026.sembrar!
    @cliente = clientes(:juan)
    @user = users(:cajero)
  end

  test "la nota de credito acredita lo mismo que la venta cobro" do
    paquete = paquete_facturable(peso: 10)
    venta   = facturar(paquete)

    nc = NotaCredito.build_from_paquetes(venta, paquete_ids: [ paquete.id ], user: @user)
    nc.save!  # el before_validation del item es donde se pisaba el monto

    assert_equal venta.venta_items.first.subtotal, nc.nota_credito_items.first.subtotal
    assert_equal venta.venta_items.first.precio_libra, nc.nota_credito_items.first.precio_libra
  end

  test "la nota de debito ajusta sobre el mismo precio que la venta" do
    paquete = paquete_facturable(peso: 10)
    venta   = facturar(paquete)

    nd = NotaDebito.build_from_paquetes(venta, paquete_ids: [ paquete.id ], user: @user)
    nd.save!

    assert_equal venta.venta_items.first.subtotal, nd.nota_debito_items.first.subtotal
  end

  test "las notas respetan el minimo del servicio" do
    # 0.5 lb de CER cae bajo el mínimo de L.173.91. Con el cálculo viejo la
    # nota decía 0.5 × 3.50 = L.1.75.
    paquete = paquete_facturable(peso: 0.5)
    venta   = facturar(paquete)

    nc = NotaCredito.build_from_paquetes(venta, paquete_ids: [ paquete.id ], user: @user)
    nc.save!  # el before_validation del item es donde se pisaba el monto

    assert_equal venta.venta_items.first.subtotal, nc.nota_credito_items.first.subtotal
    assert_in_delta 173.91, nc.nota_credito_items.first.subtotal.to_f, 0.01
  end

  test "las notas usan el escalon de peso, no un precio plano" do
    liviano = facturar(paquete_facturable(peso: 10))
    pesado  = facturar(paquete_facturable(peso: 75))

    nc_liviano = NotaCredito.build_from_paquetes(
      liviano, paquete_ids: [ liviano.venta_items.first.paquete_id ], user: @user
    ).tap(&:save!)
    nc_pesado = NotaCredito.build_from_paquetes(
      pesado, paquete_ids: [ pesado.venta_items.first.paquete_id ], user: @user
    ).tap(&:save!)

    assert_operator nc_pesado.nota_credito_items.first.precio_libra,
                    :<, nc_liviano.nota_credito_items.first.precio_libra,
                    "a 75 lb el CER baja de escalón, así que la libra sale más barata"
  end

  test "el monto queda en Lempiras, no en dolares rotulados como Lempiras" do
    paquete = paquete_facturable(peso: 10)
    venta   = facturar(paquete)

    nc = NotaCredito.build_from_paquetes(venta, paquete_ids: [ paquete.id ], user: @user)
    nc.save!  # el before_validation del item es donde se pisaba el monto

    # $45.00 sería el número sin convertir. A la tasa vigente son ~L.1,118.
    assert_operator nc.nota_credito_items.first.subtotal.to_d, :>, BigDecimal("500"),
                    "parece el monto en dólares sin convertir"
  end

  # ── El mínimo tiene que sobrevivir a facturar ──────────────────────────
  #
  # `VentaItem` tenía el mismo `before_validation` que `PreFacturaItem` pero sin
  # el guard de `minimo_aplicado`, así que al facturar recalculaba peso × precio
  # y pisaba el mínimo. La pre-factura decía L.173.91 y la factura — el
  # documento que efectivamente cobra — salía en L.55.92.

  test "el minimo de servicio sobrevive a facturar" do
    paquete = paquete_facturable(peso: 0.5)

    pf = PreFactura.build_from_paquetes(@cliente, [ paquete.id ], user: @user)
    pf.save!
    item_pf = pf.pre_factura_items.first
    assert item_pf.minimo_aplicado, "0.5 lb de CER tiene que caer en el mínimo"

    venta = pf.facturar!

    assert_equal item_pf.subtotal, venta.venta_items.first.subtotal,
                 "la factura cobra distinto de lo que la pre-factura prometió"
    assert_in_delta 173.91, venta.venta_items.first.subtotal.to_f, 0.01
  end

  test "el cobro simbolico de prepagado en Miami sobrevive a facturar" do
    paquete = paquete_facturable(peso: 10)
    paquete.update!(prepagado_miami: true)

    pf = PreFactura.build_from_paquetes(@cliente, [ paquete.id ], user: @user)
    pf.save!
    venta = pf.facturar!

    esperado = CurrencyAware.convertir(PreFactura::PREPAGADO_MIAMI_SIMBOLICO, de: "USD", a: "LPS")
    assert_in_delta esperado.to_f, venta.venta_items.first.subtotal.to_f, 0.01,
                    "el simbólico volvió a cero al facturar"
  end

  private

  def paquete_facturable(peso:)
    @seq = (@seq || 0) + 1
    Paquete.create!(
      tracking: "NOTA#{@seq}#{peso.to_s.delete('.')}",
      cliente: @cliente,
      tipo_envio: tipo_envios(:cer),
      sucursal: sucursales(:zeron_sps),
      estado: "disponible_entrega",
      peso: peso,
      peso_cobrar: peso,
      cantidad_productos: 1,
      cantidad_paquetes: 1,
      descripcion: "Paquete de prueba",
      user: users(:digitador)
    )
  end

  def facturar(paquete)
    pf = PreFactura.build_from_paquetes(@cliente, [ paquete.id ], user: @user)
    pf.save!
    pf.facturar!
  end
end
