require "test_helper"

class PreAlertaPaqueteTest < ActiveSupport::TestCase
  setup do
    @pre_alerta = pre_alertas(:activa)
  end

  test "valid pre_alerta_paquete" do
    pap = PreAlertaPaquete.new(pre_alerta: @pre_alerta, tracking: "NEWTRACK001", descripcion: "Test paquete")
    assert pap.valid?
  end

  test "requires tracking" do
    pap = PreAlertaPaquete.new(pre_alerta: @pre_alerta, tracking: "", descripcion: "Test")
    assert_not pap.valid?
    assert pap.errors[:tracking].any?
  end

  test "requires descripcion" do
    pap = PreAlertaPaquete.new(pre_alerta: @pre_alerta, tracking: "TRACK001", descripcion: "")
    assert_not pap.valid?
    assert pap.errors[:descripcion].any?
  end

  test "requires pre_alerta" do
    pap = PreAlertaPaquete.new(tracking: "NEWTRACK001", descripcion: "Test")
    assert_not pap.valid?
  end

  test "tracking must be unique per pre_alerta" do
    existing = pre_alerta_paquetes(:pap_sin_vincular)
    pap = PreAlertaPaquete.new(pre_alerta: existing.pre_alerta, tracking: existing.tracking, descripcion: "Dup")
    assert_not pap.valid?
    assert pap.errors[:tracking].any?
  end

  test "same tracking allowed on different pre_alertas" do
    pap = PreAlertaPaquete.new(
      pre_alerta: pre_alertas(:maria_pa),
      tracking: pre_alerta_paquetes(:pap_sin_vincular).tracking,
      descripcion: "Test"
    )
    assert pap.valid?
  end

  test "normalizes tracking to uppercase" do
    pap = PreAlertaPaquete.create!(pre_alerta: @pre_alerta, tracking: "  lower case track  ", descripcion: "Test")
    assert_equal "LOWER CASE TRACK", pap.tracking
  end

  test "paquete is optional" do
    pap = PreAlertaPaquete.new(pre_alerta: @pre_alerta, tracking: "OPTIONALTRACK", descripcion: "Test")
    assert pap.valid?
    assert_nil pap.paquete_id
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
