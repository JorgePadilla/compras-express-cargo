require "test_helper"

class PreAlertaPaqueteTest < ActiveSupport::TestCase
  setup do
    @pre_alerta = pre_alertas(:activa)
  end

  test "valid pre_alerta_paquete" do
    pap = PreAlertaPaquete.new(pre_alerta: @pre_alerta, tracking: "NEWTRACK001")
    assert pap.valid?
  end

  test "tracking is optional (v4)" do
    pap = PreAlertaPaquete.new(pre_alerta: @pre_alerta, tracking: "")
    assert pap.valid?
  end

  test "nil tracking is allowed" do
    pap = PreAlertaPaquete.new(pre_alerta: @pre_alerta, tracking: nil, descripcion: "Sin tracking")
    assert pap.valid?
  end

  test "blank tracking does not violate uniqueness" do
    PreAlertaPaquete.create!(pre_alerta: @pre_alerta, tracking: "", descripcion: "Uno")
    pap2 = PreAlertaPaquete.new(pre_alerta: @pre_alerta, tracking: "", descripcion: "Dos")
    assert pap2.valid?
  end

  test "requires pre_alerta" do
    pap = PreAlertaPaquete.new(tracking: "NEWTRACK001")
    assert_not pap.valid?
  end

  test "tracking must be unique per pre_alerta" do
    existing = pre_alerta_paquetes(:pap_sin_vincular)
    pap = PreAlertaPaquete.new(pre_alerta: existing.pre_alerta, tracking: existing.tracking)
    assert_not pap.valid?
    assert pap.errors[:tracking].any?
  end

  test "same tracking allowed on different pre_alertas" do
    pap = PreAlertaPaquete.new(pre_alerta: pre_alertas(:maria_pa), tracking: pre_alerta_paquetes(:pap_sin_vincular).tracking)
    assert pap.valid?
  end

  test "normalizes tracking to uppercase" do
    pap = PreAlertaPaquete.create!(pre_alerta: @pre_alerta, tracking: "  lower case track  ")
    assert_equal "LOWER CASE TRACK", pap.tracking
  end

  test "paquete is optional" do
    pap = PreAlertaPaquete.new(pre_alerta: @pre_alerta, tracking: "OPTIONALTRACK")
    assert pap.valid?
    assert_nil pap.paquete_id
  end

  # v4: valor_declarado + peso
  test "persists valor_declarado and peso with decimal precision" do
    pap = PreAlertaPaquete.create!(
      pre_alerta: @pre_alerta,
      tracking: "VALTRACK001",
      descripcion: "Con valor y peso",
      valor_declarado: 123.45,
      peso: 7.89
    )
    pap.reload
    assert_equal BigDecimal("123.45"), pap.valor_declarado
    assert_equal BigDecimal("7.89"), pap.peso
  end

  test "valor_declarado and peso are optional" do
    pap = PreAlertaPaquete.new(pre_alerta: @pre_alerta, tracking: "NOEXTRA001")
    assert pap.valid?
    assert_nil pap.valor_declarado
    assert_nil pap.peso
  end

  # Scopes
  test "sin_vincular returns unlinked records" do
    result = PreAlertaPaquete.sin_vincular
    assert result.all? { |pap| pap.paquete_id.nil? }
  end

  test "vinculados returns linked records" do
    pap = pre_alerta_paquetes(:pap_sin_vincular)
    pap.update!(paquete: paquetes(:recibido))

    result = PreAlertaPaquete.vinculados
    assert result.all? { |pap| pap.paquete_id.present? }
    assert_includes result, pap
  end
end
