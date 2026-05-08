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
    pap = PreAlertaPaquete.create!(pre_alerta: @pre_alerta, tracking: "lowercase123", descripcion: "Test")
    assert_equal "LOWERCASE123", pap.tracking
  end

  test "should reject tracking with spaces" do
    pap = PreAlertaPaquete.new(pre_alerta: @pre_alerta, tracking: "ABC 123", descripcion: "Test")
    assert_not pap.valid?
    assert pap.errors[:tracking].any?
  end

  test "should reject tracking with special characters" do
    pap = PreAlertaPaquete.new(pre_alerta: @pre_alerta, tracking: "ABC@123!", descripcion: "Test")
    assert_not pap.valid?
    assert pap.errors[:tracking].any?
  end

  test "should accept alphanumeric tracking" do
    pap = PreAlertaPaquete.new(pre_alerta: @pre_alerta, tracking: "ABC123", descripcion: "Test")
    assert pap.valid?
  end

  test "should accept tracking with hyphens" do
    pap = PreAlertaPaquete.new(pre_alerta: @pre_alerta, tracking: "ABC-123-DEF", descripcion: "Test")
    assert pap.valid?
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

  # Eager-creation: al crear un PAP nuevo se materializa un Paquete en
  # estado pre_alerta_estado para que aparezca en /paquetes inmediatamente.
  test "after_create materializes a Paquete in pre_alerta_estado" do
    assert_difference -> { Paquete.count }, +1 do
      @pap = PreAlertaPaquete.create!(
        pre_alerta: @pre_alerta, tracking: "EAGER001", descripcion: "Test eager"
      )
    end
    p = @pap.reload.paquete
    assert_not_nil p
    assert_equal "pre_alerta_estado", p.estado
    assert_equal "EAGER001", p.tracking
    assert_equal "Test eager", p.descripcion
    assert_equal @pre_alerta.cliente_id, p.cliente_id
    assert_equal @pre_alerta.tipo_envio_id, p.tipo_envio_id
  end

  test "after_create skips paquete creation if paquete_id already set" do
    paquete_existente = paquetes(:recibido)
    assert_no_difference -> { Paquete.count } do
      PreAlertaPaquete.create!(
        pre_alerta: @pre_alerta,
        tracking: "PRELINKED001",
        descripcion: "Already linked",
        paquete: paquete_existente
      )
    end
  end

  test "after_update syncs tracking + descripcion to esperado paquete" do
    pap = PreAlertaPaquete.create!(
      pre_alerta: @pre_alerta, tracking: "SYNC001", descripcion: "Original"
    )
    p = pap.reload.paquete
    pap.update!(tracking: "SYNC002", descripcion: "Editado")
    assert_equal "SYNC002", p.reload.tracking
    assert_equal "Editado", p.descripcion
  end

  test "after_update does NOT sync once paquete left pre_alerta_estado" do
    pap = PreAlertaPaquete.create!(
      pre_alerta: @pre_alerta, tracking: "RECVD001", descripcion: "Original"
    )
    p = pap.reload.paquete
    p.update!(estado: "recibido_miami")
    pap.update!(descripcion: "Editado tarde")
    assert_equal "Original", p.reload.descripcion
  end

  test "before_destroy anula the esperado paquete" do
    pap = PreAlertaPaquete.create!(
      pre_alerta: @pre_alerta, tracking: "ANUL001", descripcion: "To destroy"
    )
    p = pap.reload.paquete
    pap.destroy!
    assert_equal "anulado", p.reload.estado
  end

  test "before_destroy does NOT touch paquete already past pre_alerta_estado" do
    pap = PreAlertaPaquete.create!(
      pre_alerta: @pre_alerta, tracking: "KEEP001", descripcion: "Already received"
    )
    p = pap.reload.paquete
    p.update!(estado: "empacado")
    pap.destroy!
    assert_equal "empacado", p.reload.estado
  end
end
