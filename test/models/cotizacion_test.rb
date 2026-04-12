require "test_helper"

class CotizacionTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
    @user = users(:cajero)
  end

  test "auto-generates numero on create" do
    ct = Cotizacion.create!(cliente: @cliente, estado: "borrador")
    assert_match /\ACT-\d{6}\z/, ct.numero
  end

  test "requires unique numero" do
    Cotizacion.create!(numero: "CT-999999", cliente: @cliente, estado: "borrador")
    dup = Cotizacion.new(numero: "CT-999999", cliente: @cliente, estado: "borrador")
    assert_not dup.valid?
  end

  test "validates moneda inclusion" do
    ct = Cotizacion.new(cliente: @cliente, estado: "borrador", moneda: "EUR")
    assert_not ct.valid?
    assert ct.errors[:moneda].any?
  end

  test "calculate_totals applies ISV" do
    ct = Cotizacion.new(cliente: @cliente, estado: "borrador")
    ct.cotizacion_items.build(concepto: "Flete", peso_cobrar: 10, precio_libra: 5, subtotal: 50)
    ct.save!
    assert_equal 50.to_d, ct.subtotal.to_d
    assert_equal "7.50".to_d, ct.impuesto.to_d
    assert_equal "57.50".to_d, ct.total.to_d
  end

  test "enviar! transitions borrador to enviada" do
    ct = cotizaciones(:borrador_juan)
    assert ct.enviar!
    assert ct.enviada?
    assert_not_nil ct.enviada_at
  end

  test "enviar! fails for non-borrador" do
    ct = cotizaciones(:enviada_maria)
    assert_not ct.enviar!
  end

  test "aceptar! transitions enviada to aceptada" do
    ct = cotizaciones(:enviada_maria)
    assert ct.aceptar!
    assert ct.aceptada?
    assert_not_nil ct.aceptada_at
  end

  test "rechazar! transitions enviada to rechazada" do
    ct = cotizaciones(:enviada_maria)
    assert ct.rechazar!
    assert ct.rechazada?
    assert_not_nil ct.rechazada_at
  end

  test "generar_proforma! creates venta with estado proforma" do
    ct = cotizaciones(:aceptada_juan)
    assert_difference "Venta.count", 1 do
      proforma = ct.generar_proforma!(user: @user)
      assert_equal "proforma", proforma.estado
      assert_equal ct.cliente, proforma.cliente
      assert_equal ct.total.to_d, proforma.total.to_d
    end
    ct.reload
    assert_not_nil ct.venta_id
  end

  test "generar_proforma! returns nil for non-aceptada" do
    ct = cotizaciones(:borrador_juan)
    assert_nil ct.generar_proforma!(user: @user)
  end

  test "generar_proforma! returns existing venta if already generated" do
    ct = cotizaciones(:aceptada_juan)
    proforma1 = ct.generar_proforma!(user: @user)
    ct.reload
    proforma2 = ct.generar_proforma!(user: @user)
    assert_equal proforma1, proforma2
  end

  test "marcar_expiradas! expires overdue enviadas" do
    ct = cotizaciones(:enviada_maria)
    ct.update!(fecha_vencimiento: 1.day.ago)
    Cotizacion.marcar_expiradas!
    assert ct.reload.expirada?
  end

  test "sets fecha_vencimiento from vigencia_dias" do
    ct = Cotizacion.create!(cliente: @cliente, estado: "borrador", vigencia_dias: 15)
    assert_not_nil ct.fecha_vencimiento
  end

  test "simbolo_moneda returns correct symbol" do
    ct = Cotizacion.new(moneda: "LPS")
    assert_equal "L.", ct.simbolo_moneda
    ct.moneda = "USD"
    assert_equal "$", ct.simbolo_moneda
  end
end
