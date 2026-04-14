require "test_helper"

class Cuenta::PreAlertasMoveTest < ActionDispatch::IntegrationTest
  setup do
    @cliente = clientes(:juan)
    post session_url, params: { email_address: @cliente.email, password: "Cliente123!" }
    @origen = pre_alertas(:recibida) # consolidado=true, tipo_envio=aereo
    @destino = pre_alertas(:consolidada_destino) # consolidado=true, tipo_envio=aereo
  end

  # ── Move unlinked paquete ──

  test "move unlinked paquete to consolidado PA succeeds" do
    pap = pre_alerta_paquetes(:pap_sin_vincular) # unlinked, belongs to :activa
    origen = pre_alertas(:activa)
    # activa is not consolidado, but unlinked paquetes can move to any consolidado destination
    post mover_paquete_cuenta_pre_alerta_url(origen), params: {
      pre_alerta_paquete_id: pap.id,
      destino_id: @destino.id
    }

    assert_redirected_to edit_cuenta_pre_alerta_url(origen)
    pap.reload
    assert_equal @destino.id, pap.pre_alerta_id
    assert_match "movido", flash[:notice]
  end

  test "move unlinked paquete appends notes to both PAs" do
    pap = pre_alerta_paquetes(:pap_sin_vincular)
    origen = pre_alertas(:activa)

    post mover_paquete_cuenta_pre_alerta_url(origen), params: {
      pre_alerta_paquete_id: pap.id,
      destino_id: @destino.id
    }

    origen.reload
    @destino.reload
    assert_match "movido a #{@destino.numero_documento}", origen.historial
    assert_match "recibido de #{origen.numero_documento}", @destino.historial
  end

  # ── Move linked paquete (recibido_miami) ──

  test "move linked paquete to same tipo_envio consolidado PA succeeds" do
    pap = pre_alerta_paquetes(:pap_vinculado) # linked to paquetes(:recibido), in :recibida
    # recibida: consolidado=true, tipo_envio=aereo
    # consolidada_destino: consolidado=true, tipo_envio=aereo — same tipo
    post mover_paquete_cuenta_pre_alerta_url(@origen), params: {
      pre_alerta_paquete_id: pap.id,
      destino_id: @destino.id
    }

    assert_redirected_to edit_cuenta_pre_alerta_url(@origen)
    pap.reload
    assert_equal @destino.id, pap.pre_alerta_id
  end

  # ── Blocked scenarios ──

  test "move linked paquete to different tipo_envio is blocked" do
    pap = pre_alerta_paquetes(:pap_vinculado)
    # maria_pa belongs to maria, not juan — scoped find raises RecordNotFound → 404
    destino_maritimo = pre_alertas(:maria_pa)
    post mover_paquete_cuenta_pre_alerta_url(@origen), params: {
      pre_alerta_paquete_id: pap.id,
      destino_id: destino_maritimo.id
    }
    assert_response :not_found
  end

  test "move linked paquete with en_aduana estado is blocked" do
    pap = pre_alerta_paquetes(:pap_vinculado)
    pap.paquete.update_column(:estado, "en_aduana")

    post mover_paquete_cuenta_pre_alerta_url(@origen), params: {
      pre_alerta_paquete_id: pap.id,
      destino_id: @destino.id
    }

    assert_redirected_to edit_cuenta_pre_alerta_url(@origen)
    assert_match "No se puede mover", flash[:alert]
    pap.reload
    assert_equal @origen.id, pap.pre_alerta_id
  end

  test "move linked paquete with entregado estado is blocked" do
    pap = pre_alerta_paquetes(:pap_vinculado)
    pap.paquete.update_column(:estado, "entregado")

    post mover_paquete_cuenta_pre_alerta_url(@origen), params: {
      pre_alerta_paquete_id: pap.id,
      destino_id: @destino.id
    }

    assert_redirected_to edit_cuenta_pre_alerta_url(@origen)
    assert_match "No se puede mover", flash[:alert]
  end

  test "move to CKA destination is blocked" do
    pap = pre_alerta_paquetes(:pap_sin_vincular)
    origen = pre_alertas(:activa)
    cka_dest = pre_alertas(:cka_pa)

    post mover_paquete_cuenta_pre_alerta_url(origen), params: {
      pre_alerta_paquete_id: pap.id,
      destino_id: cka_dest.id
    }

    assert_redirected_to edit_cuenta_pre_alerta_url(origen)
    assert_match "no valido", flash[:alert]
    pap.reload
    assert_equal origen.id, pap.pre_alerta_id
  end

  test "cannot move to another clients PA" do
    pap = pre_alerta_paquetes(:pap_sin_vincular)
    origen = pre_alertas(:activa)
    maria_pa = pre_alertas(:maria_pa)

    post mover_paquete_cuenta_pre_alerta_url(origen), params: {
      pre_alerta_paquete_id: pap.id,
      destino_id: maria_pa.id
    }
    assert_response :not_found
  end

  # ── destinos_disponibles JSON ──

  test "destinos_disponibles returns filtered list for unlinked paquete" do
    pap = pre_alerta_paquetes(:pap_sin_vincular)
    origen = pre_alertas(:activa)

    get destinos_disponibles_cuenta_pre_alerta_url(origen), params: {
      pre_alerta_paquete_id: pap.id
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_kind_of Array, body

    # Should include consolidado PAs but not CKA/CKM or current PA
    ids = body.map { |d| d["id"] }
    assert_includes ids, @destino.id
    assert_includes ids, @origen.id # recibida is consolidado=true
    assert_not_includes ids, pre_alertas(:cka_pa).id
    assert_not_includes ids, origen.id
  end

  test "destinos_disponibles returns same-tipo for linked paquete" do
    pap = pre_alerta_paquetes(:pap_vinculado)

    get destinos_disponibles_cuenta_pre_alerta_url(@origen), params: {
      pre_alerta_paquete_id: pap.id
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    ids = body.map { |d| d["id"] }
    assert_includes ids, @destino.id
    assert_not_includes ids, @origen.id
  end

  test "destinos_disponibles returns empty for en_aduana paquete" do
    pap = pre_alerta_paquetes(:pap_vinculado)
    pap.paquete.update_column(:estado, "en_aduana")

    get destinos_disponibles_cuenta_pre_alerta_url(@origen), params: {
      pre_alerta_paquete_id: pap.id
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [], body
  end
end
