require "test_helper"

class PreAlertaTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
    @tipo_envio = tipo_envios(:aereo)
  end

  # Validations
  test "valid pre_alerta" do
    pa = PreAlerta.new(cliente: @cliente, tipo_envio: @tipo_envio, creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    assert pa.valid?
  end

  test "requires cliente" do
    pa = PreAlerta.new(tipo_envio: @tipo_envio)
    assert_not pa.valid?
    assert pa.errors[:cliente].any?
  end

  test "requires tipo_envio" do
    # When no CER exists, PreAlerta without tipo_envio is invalid.
    TipoEnvio.where(codigo: "cer").destroy_all
    pa = PreAlerta.new(cliente: @cliente)
    assert_not pa.valid?
    assert pa.errors[:tipo_envio].any?
  end

  test "requires estado" do
    pa = PreAlerta.new(cliente: @cliente, tipo_envio: @tipo_envio, estado: nil)
    assert_not pa.valid?
  end

  test "numero_documento must be unique" do
    pa = PreAlerta.new(cliente: @cliente, tipo_envio: @tipo_envio, numero_documento: pre_alertas(:activa).numero_documento)
    assert_not pa.valid?
    assert pa.errors[:numero_documento].any?
  end

  # Auto-generation
  test "auto-generates PA-XXXXXX numero_documento" do
    pa = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    assert_match(/\APA-\d{6}\z/, pa.numero_documento)
  end

  test "generates sequential numero_documento" do
    pa1 = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    pa2 = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    num1 = pa1.numero_documento.sub("PA-", "").to_i
    num2 = pa2.numero_documento.sub("PA-", "").to_i
    assert_equal num1 + 1, num2
  end

  test "retries on duplicate numero_documento" do
    pa = PreAlerta.new(cliente: @cliente, tipo_envio: @tipo_envio, creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    assert_nothing_raised { pa.save! }
  end

  # Defaults
  test "defaults estado to pre_alerta" do
    pa = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    assert_equal "pre_alerta", pa.estado
  end

  test "defaults consolidado to false" do
    pa = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    assert_equal false, pa.consolidado
  end

  test "defaults con_reempaque to false" do
    pa = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    assert_equal false, pa.con_reempaque
  end

  test "defaults notificado to false" do
    pa = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    assert_equal false, pa.notificado
  end

  # Enum
  test "estado enum values" do
    assert_equal %w[pre_alerta recibido enviado en_aduana disponible facturado anulado], PreAlerta.estados.keys
  end

  # Scopes
  test "activas excludes anulados and deleted" do
    activa = pre_alertas(:activa)
    anulada = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, estado: "anulado",
      creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    deleted = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, deleted_at: Time.current,
      creado_por_tipo: "cliente", creado_por_id: @cliente.id)

    result = PreAlerta.activas
    assert_includes result, activa
    assert_not_includes result, anulada
    assert_not_includes result, deleted
  end

  test "buscar by numero_documento" do
    result = PreAlerta.buscar("PA-000001")
    assert_includes result, pre_alertas(:activa)
  end

  test "buscar by cliente codigo" do
    result = PreAlerta.buscar("CEC-001")
    assert_includes result, pre_alertas(:activa)
  end

  test "by_estado filters correctly" do
    result = PreAlerta.by_estado("pre_alerta")
    assert_includes result, pre_alertas(:activa)
    assert_not_includes result, pre_alertas(:recibida)
  end

  test "by_cliente filters correctly" do
    result = PreAlerta.by_cliente(@cliente.id)
    assert_includes result, pre_alertas(:activa)
    assert_not_includes result, pre_alertas(:maria_pa)
  end

  test "recientes orders by created_at desc" do
    # Create records with explicit timestamps to test ordering
    pa1 = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, creado_por_tipo: "cliente", creado_por_id: @cliente.id, created_at: 2.days.ago)
    pa2 = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, creado_por_tipo: "cliente", creado_por_id: @cliente.id, created_at: 1.day.ago)

    result = PreAlerta.where(id: [pa1.id, pa2.id]).recientes.to_a
    assert_equal [pa2, pa1], result
  end

  # Methods
  test "anular! changes estado to anulado" do
    pa = pre_alertas(:activa)
    pa.anular!
    assert_equal "anulado", pa.reload.estado
  end

  # Nested attributes
  test "accepts nested pre_alerta_paquetes" do
    pa = PreAlerta.create!(
      cliente: @cliente,
      tipo_envio: @tipo_envio,
      creado_por_tipo: "cliente",
      creado_por_id: @cliente.id,
      pre_alerta_paquetes_attributes: [
        { tracking: "TRACK001", descripcion: "Test" },
        { tracking: "TRACK002", descripcion: "Test2" }
      ]
    )
    assert_equal 2, pa.pre_alerta_paquetes.count
  end

  test "rejects fully blank rows in nested attributes" do
    pa = PreAlerta.create!(
      cliente: @cliente,
      tipo_envio: @tipo_envio,
      creado_por_tipo: "cliente",
      creado_por_id: @cliente.id,
      pre_alerta_paquetes_attributes: [
        { tracking: "", descripcion: "" },
        { tracking: "TRACK001", descripcion: "Test2" }
      ]
    )
    assert_equal 1, pa.pre_alerta_paquetes.count
  end

  test "requires tracking and descripcion on paquetes" do
    pa = PreAlerta.new(
      cliente: @cliente,
      tipo_envio: @tipo_envio,
      creado_por_tipo: "cliente",
      creado_por_id: @cliente.id,
      pre_alerta_paquetes_attributes: [
        { tracking: "", descripcion: "Sin tracking" }
      ]
    )
    assert_not pa.valid?
  end

  test "rejects rows where instrucciones is also blank" do
    pa = PreAlerta.create!(
      cliente: @cliente,
      tipo_envio: @tipo_envio,
      creado_por_tipo: "cliente",
      creado_por_id: @cliente.id,
      pre_alerta_paquetes_attributes: [
        { tracking: "", descripcion: "", instrucciones: "" }
      ]
    )
    assert_equal 0, pa.pre_alerta_paquetes.count
  end

  # ── v4: default tipo_envio ──
  test "assigns default CER when tipo_envio is not provided" do
    cer = tipo_envios(:cer)
    pa = PreAlerta.new(cliente: @cliente, creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    assert pa.valid?
    assert_equal cer, pa.tipo_envio
  end

  test "does not override explicitly set tipo_envio" do
    express = tipo_envios(:express)
    pa = PreAlerta.new(cliente: @cliente, tipo_envio: express, creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    assert pa.valid?
    assert_equal express, pa.tipo_envio
  end

  # ── v4: max_paquetes_por_accion ──
  test "CKA rejects more than 1 paquete" do
    cka = tipo_envios(:cka)
    pa = PreAlerta.new(
      cliente: @cliente,
      tipo_envio: cka,
      creado_por_tipo: "cliente",
      creado_por_id: @cliente.id,
      pre_alerta_paquetes_attributes: [
        { tracking: "CKA001", descripcion: "Paquete 1" },
        { tracking: "CKA002", descripcion: "Paquete 2" }
      ]
    )
    assert_not pa.valid?
    assert pa.errors[:base].any? { |m| m.include?("CKA") && m.include?("1 paquete") }
  end

  test "CKM rejects more than 1 paquete" do
    ckm = tipo_envios(:ckm)
    pa = PreAlerta.new(
      cliente: @cliente,
      tipo_envio: ckm,
      creado_por_tipo: "cliente",
      creado_por_id: @cliente.id,
      pre_alerta_paquetes_attributes: [
        { tracking: "CKM001", descripcion: "Paquete 1" },
        { tracking: "CKM002", descripcion: "Paquete 2" }
      ]
    )
    assert_not pa.valid?
    assert pa.errors[:base].any? { |m| m.include?("CKM") }
  end

  test "CKA accepts exactly 1 paquete" do
    cka = tipo_envios(:cka)
    pa = PreAlerta.new(
      cliente: @cliente,
      tipo_envio: cka,
      creado_por_tipo: "cliente",
      creado_por_id: @cliente.id,
      pre_alerta_paquetes_attributes: [
        { tracking: "CKA-SINGLE", descripcion: "Solo uno" }
      ]
    )
    assert pa.valid?, "Expected CKA with 1 paquete to be valid, got: #{pa.errors.full_messages.join(', ')}"
  end

  test "CER (no limit) accepts multiple paquetes" do
    cer = tipo_envios(:cer)
    pa = PreAlerta.new(
      cliente: @cliente,
      tipo_envio: cer,
      creado_por_tipo: "cliente",
      creado_por_id: @cliente.id,
      pre_alerta_paquetes_attributes: [
        { tracking: "CER001", descripcion: "Uno" },
        { tracking: "CER002", descripcion: "Dos" },
        { tracking: "CER003", descripcion: "Tres" }
      ]
    )
    assert pa.valid?
  end
end
