require "test_helper"

class PreAlertaTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
    @tipo_envio = tipo_envios(:aereo)
  end

  # Validations
  test "valid pre_alerta" do
    pa = PreAlerta.new(cliente: @cliente, tipo_envio: @tipo_envio, titulo: "Test", creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    assert pa.valid?
  end

  test "requires cliente" do
    pa = PreAlerta.new(tipo_envio: @tipo_envio, titulo: "Test")
    assert_not pa.valid?
    assert pa.errors[:cliente].any?
  end

  test "requires tipo_envio" do
    # When no CER exists, PreAlerta without tipo_envio is invalid.
    TipoEnvio.where(codigo: "cer").destroy_all
    pa = PreAlerta.new(cliente: @cliente, titulo: "Test")
    assert_not pa.valid?
    assert pa.errors[:tipo_envio].any?
  end

  test "requires estado" do
    pa = PreAlerta.new(cliente: @cliente, tipo_envio: @tipo_envio, titulo: "Test", estado: nil)
    assert_not pa.valid?
  end

  test "requires titulo" do
    pa = PreAlerta.new(cliente: @cliente, tipo_envio: @tipo_envio, creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    assert_not pa.valid?
    assert pa.errors[:titulo].any?
  end

  test "numero_documento must be unique" do
    pa = PreAlerta.new(cliente: @cliente, tipo_envio: @tipo_envio, numero_documento: pre_alertas(:activa).numero_documento)
    assert_not pa.valid?
    assert pa.errors[:numero_documento].any?
  end

  # Auto-generation
  test "auto-generates PA-XXXXXX numero_documento" do
    pa = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, titulo: "Test", creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    assert_match(/\APA-\d{6}\z/, pa.numero_documento)
  end

  test "generates sequential numero_documento" do
    pa1 = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, titulo: "Test", creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    pa2 = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, titulo: "Test", creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    num1 = pa1.numero_documento.sub("PA-", "").to_i
    num2 = pa2.numero_documento.sub("PA-", "").to_i
    assert_equal num1 + 1, num2
  end

  test "retries on duplicate numero_documento" do
    pa = PreAlerta.new(cliente: @cliente, tipo_envio: @tipo_envio, titulo: "Test", creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    assert_nothing_raised { pa.save! }
  end

  # Defaults
  test "defaults estado to pre_alerta" do
    pa = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, titulo: "Test", creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    assert_equal "pre_alerta", pa.estado
  end

  test "defaults consolidado to false" do
    pa = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, titulo: "Test", creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    assert_equal false, pa.consolidado
  end

  test "defaults con_reempaque to false" do
    pa = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, titulo: "Test", creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    assert_equal false, pa.con_reempaque
  end

  test "defaults notificado to false" do
    pa = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, titulo: "Test", creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    assert_equal false, pa.notificado
  end

  # Enum
  test "estado enum values" do
    assert_equal %w[pre_alerta recibido enviado en_aduana disponible facturado anulado], PreAlerta.estados.keys
  end

  # Scopes
  test "activas excludes anulados and deleted" do
    activa = pre_alertas(:activa)
    anulada = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, titulo: "Anulada", estado: "anulado",
      creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    deleted = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, titulo: "Deleted", deleted_at: Time.current,
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
    pa1 = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, titulo: "Test1", creado_por_tipo: "cliente", creado_por_id: @cliente.id, created_at: 2.days.ago)
    pa2 = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, titulo: "Test2", creado_por_tipo: "cliente", creado_por_id: @cliente.id, created_at: 1.day.ago)

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
      titulo: "Test",
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
      titulo: "Test",
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
      titulo: "Test",
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
      titulo: "Test",
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
    pa = PreAlerta.new(cliente: @cliente, titulo: "Test", creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    assert pa.valid?
    assert_equal cer, pa.tipo_envio
  end

  test "does not override explicitly set tipo_envio" do
    express = tipo_envios(:express)
    pa = PreAlerta.new(cliente: @cliente, tipo_envio: express, titulo: "Test", creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    assert pa.valid?
    assert_equal express, pa.tipo_envio
  end

  # ── v4: max_paquetes_por_accion ──
  test "CKA rejects more than 1 paquete" do
    cka = tipo_envios(:cka)
    pa = PreAlerta.new(
      cliente: @cliente,
      tipo_envio: cka,
      titulo: "Test",
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
      titulo: "Test",
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
      titulo: "Test",
      creado_por_tipo: "cliente",
      creado_por_id: @cliente.id,
      pre_alerta_paquetes_attributes: [
        { tracking: "CKASINGLE", descripcion: "Solo uno" }
      ]
    )
    assert pa.valid?, "Expected CKA with 1 paquete to be valid, got: #{pa.errors.full_messages.join(', ')}"
  end

  # ── Auto-sync from paquetes ──
  test "actualizar_estado_from_paquetes! advances estado based on paquete minimum" do
    # Create a fresh pre-alerta with a single linked paquete in disponible_entrega
    pa = PreAlerta.create!(
      cliente: @cliente, tipo_envio: @tipo_envio, titulo: "Sync test",
      estado: "recibido", creado_por_tipo: "cliente", creado_por_id: @cliente.id
    )
    paquete = paquetes(:disponible_entrega_juan)
    pa.pre_alerta_paquetes.create!(
      tracking: paquete.tracking, descripcion: "Test", paquete: paquete
    )

    # disponible_entrega maps to "disponible", which is ahead of "recibido"
    pa.actualizar_estado_from_paquetes!
    assert_equal "disponible", pa.reload.estado
  end

  test "actualizar_estado_from_paquetes! takes minimum of multiple paquetes" do
    pa = pre_alertas(:recibida)
    # pap_vinculado links to :recibido (recibido_miami → "recibido")
    # pap_disponible_juan links to :disponible_entrega_juan (disponible_entrega → "disponible")
    # Minimum is "recibido", same as current → no change
    pa.actualizar_estado_from_paquetes!
    assert_equal "recibido", pa.reload.estado
  end

  test "actualizar_estado_from_paquetes! never retrocedes estado" do
    pa = PreAlerta.create!(
      cliente: @cliente, tipo_envio: @tipo_envio, titulo: "No retrocede",
      estado: "en_aduana", creado_por_tipo: "cliente", creado_por_id: @cliente.id
    )
    paquete = paquetes(:recibido) # recibido_miami → "recibido"
    pa.pre_alerta_paquetes.create!(
      tracking: paquete.tracking, descripcion: "Test", paquete: paquete
    )

    # "recibido" < "en_aduana" → no change
    pa.actualizar_estado_from_paquetes!
    assert_equal "en_aduana", pa.reload.estado
  end

  test "actualizar_estado_from_paquetes! skips anulado pre-alertas" do
    pa = PreAlerta.create!(
      cliente: @cliente, tipo_envio: @tipo_envio, titulo: "Anulado test",
      estado: "anulado", creado_por_tipo: "cliente", creado_por_id: @cliente.id
    )
    paquete = paquetes(:disponible_entrega_juan)
    pa.pre_alerta_paquetes.create!(
      tracking: paquete.tracking, descripcion: "Test", paquete: paquete
    )

    pa.actualizar_estado_from_paquetes!
    assert_equal "anulado", pa.reload.estado
  end

  test "actualizar_estado_from_paquetes! does nothing when no linked paquetes" do
    pa = pre_alertas(:activa) # has no linked paquetes (pap_sin_vincular has no paquete_id)
    pa.actualizar_estado_from_paquetes!
    assert_equal "pre_alerta", pa.reload.estado
  end

  test "paquete estado change triggers pre-alerta sync via callback" do
    pa = PreAlerta.create!(
      cliente: @cliente, tipo_envio: @tipo_envio, titulo: "Callback test",
      estado: "recibido", creado_por_tipo: "cliente", creado_por_id: @cliente.id
    )
    paquete = Paquete.create!(
      tracking: "SYNCCALLBACK001", cliente: @cliente,
      estado: "recibido_miami", peso: 5, peso_cobrar: 5
    )
    pa.pre_alerta_paquetes.create!(
      tracking: paquete.tracking, descripcion: "Test", paquete: paquete
    )

    # Change paquete to enviado_honduras → maps to "enviado" → ahead of "recibido"
    paquete.update!(estado: "enviado_honduras")
    assert_equal "enviado", pa.reload.estado
  end

  # ── Finalizado + Consolidando ──
  test "finalizado defaults to false" do
    pa = PreAlerta.create!(cliente: @cliente, tipo_envio: @tipo_envio, titulo: "Test", creado_por_tipo: "cliente", creado_por_id: @cliente.id)
    assert_equal false, pa.finalizado?
  end

  test "consolidando? returns true for consolidado non-finalized" do
    pa = pre_alertas(:consolidada_destino)
    assert pa.consolidado?
    assert_not pa.finalizado?
    assert pa.consolidando?
  end

  test "consolidando? returns false for finalized" do
    pa = pre_alertas(:finalizada)
    assert pa.consolidado?
    assert pa.finalizado?
    assert_not pa.consolidando?
  end

  test "consolidando? returns false for non-consolidado" do
    pa = pre_alertas(:activa)
    assert_not pa.consolidado?
    assert_not pa.consolidando?
  end

  test "append_historial! appends to nil historial" do
    pa = pre_alertas(:activa)
    assert_nil pa.historial
    pa.append_historial!("First entry")
    assert_equal "First entry", pa.reload.historial
  end

  test "append_historial! appends to existing historial" do
    pa = pre_alertas(:activa)
    pa.update_column(:historial, "Line 1")
    pa.append_historial!("Line 2")
    assert_equal "Line 1\nLine 2", pa.reload.historial
  end

  test "tipo_envio_descripcion for aereo con reempaque" do
    cer = tipo_envios(:cer)
    pa = PreAlerta.new(tipo_envio: cer)
    assert_equal "Aereo con Reempaque", pa.tipo_envio_descripcion
  end

  test "tipo_envio_descripcion for aereo sin reempaque" do
    cka = tipo_envios(:cka)
    pa = PreAlerta.new(tipo_envio: cka)
    assert_equal "Aereo sin Reempaque", pa.tipo_envio_descripcion
  end

  test "CER (no limit) accepts multiple paquetes" do
    cer = tipo_envios(:cer)
    pa = PreAlerta.new(
      cliente: @cliente,
      tipo_envio: cer,
      titulo: "Test",
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
