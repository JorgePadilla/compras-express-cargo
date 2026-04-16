require "test_helper"

class Cuenta::PreAlertasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cliente = clientes(:juan)
    post session_url, params: { email_address: @cliente.email, password: "Cliente123!" }
    @pre_alerta = pre_alertas(:activa)
  end

  # Index
  test "should get index" do
    get cuenta_pre_alertas_url
    assert_response :success
  end

  test "should filter by search" do
    get cuenta_pre_alertas_url, params: { q: "PA-000001" }
    assert_response :success
  end

  test "should filter by estado" do
    get cuenta_pre_alertas_url, params: { estado: "pre_alerta" }
    assert_response :success
  end

  # Show
  test "should show pre_alerta" do
    get cuenta_pre_alerta_url(@pre_alerta)
    assert_response :success
  end

  test "should not show another clients pre_alerta" do
    other = pre_alertas(:maria_pa)
    get cuenta_pre_alerta_url(other)
    assert_response :not_found
  end

  # New (wizard)
  test "should get new step 1" do
    get new_cuenta_pre_alerta_url
    assert_response :success
  end

  test "should get new step 2 after selecting consolidable service" do
    post cuenta_pre_alertas_url, params: { wizard_step: 1, tipo_envio_id: tipo_envios(:cer).id }
    get new_cuenta_pre_alerta_url(step: 2)
    assert_response :success
  end

  test "should get new step 3" do
    post cuenta_pre_alertas_url, params: { wizard_step: 1, tipo_envio_id: tipo_envios(:cer).id }
    post cuenta_pre_alertas_url, params: { wizard_step: 2, consolidado: "0" }
    get new_cuenta_pre_alerta_url(step: 3)
    assert_response :success
  end

  # Create via wizard
  test "wizard step 1 with consolidable service redirects to step 2" do
    post cuenta_pre_alertas_url, params: { wizard_step: 1, tipo_envio_id: tipo_envios(:cer).id }
    assert_redirected_to new_cuenta_pre_alerta_url(step: 2)
  end

  test "wizard step 1 with CKA skips to step 3 and sets consolidado false" do
    post cuenta_pre_alertas_url, params: { wizard_step: 1, tipo_envio_id: tipo_envios(:cka).id }
    assert_redirected_to new_cuenta_pre_alerta_url(step: 3)
  end

  test "wizard step 1 without tipo_envio redirects back with alert" do
    post cuenta_pre_alertas_url, params: { wizard_step: 1 }
    assert_redirected_to new_cuenta_pre_alerta_url(step: 1)
  end

  test "wizard step 2 stores consolidado in session" do
    post cuenta_pre_alertas_url, params: { wizard_step: 1, tipo_envio_id: tipo_envios(:cer).id }
    post cuenta_pre_alertas_url, params: { wizard_step: 2, consolidado: "1" }
    assert_redirected_to new_cuenta_pre_alerta_url(step: 3)
  end

  test "wizard step 3 creates pre_alerta with paquete data" do
    # Setup wizard session: CER + no consolidar
    post cuenta_pre_alertas_url, params: { wizard_step: 1, tipo_envio_id: tipo_envios(:cer).id }
    post cuenta_pre_alertas_url, params: { wizard_step: 2, consolidado: "0" }

    assert_difference("PreAlerta.count", 1) do
      assert_difference("PreAlertaPaquete.count", 1) do
        post cuenta_pre_alertas_url, params: {
          wizard_step: 3,
          titulo: "Televisor",
          proveedor: "Best Buy",
          tracking: "WIZTRACK001",
          descripcion: "Paquete desde wizard"
        }
      end
    end

    pa = PreAlerta.last
    assert_redirected_to cuenta_root_url
    assert_equal tipo_envios(:cer), pa.tipo_envio
    assert pa.con_reempaque?
    assert_not pa.consolidado?
    assert_equal "cliente", pa.creado_por_tipo
    assert_equal "Televisor", pa.titulo
    assert_equal "Best Buy", pa.proveedor

    pap = pa.pre_alerta_paquetes.first
    assert_equal "WIZTRACK001", pap.tracking
    assert_equal "Paquete desde wizard", pap.descripcion
  end

  test "wizard step 3 agregar_otro preserves wizard session and redirects to edit" do
    post cuenta_pre_alertas_url, params: { wizard_step: 1, tipo_envio_id: tipo_envios(:cer).id }
    post cuenta_pre_alertas_url, params: { wizard_step: 2, consolidado: "1" }

    assert_difference("PreAlerta.count", 1) do
      post cuenta_pre_alertas_url, params: {
        wizard_step: 3,
        agregar_otro: "1",
        titulo: "Ropa",
        proveedor: "Shein",
        tracking: "AGROTRO001",
        descripcion: "Camisetas"
      }
    end

    pa = PreAlerta.last
    assert_redirected_to edit_cuenta_pre_alerta_url(pa, agregar: 1)
    assert_match "Agrega más paquetes", flash[:notice]

    # Wizard session must be preserved so the user can reuse it
    follow_redirect!
    assert session[:pre_alerta_wizard].present?
    assert_equal tipo_envios(:cer).id, session[:pre_alerta_wizard]["tipo_envio_id"]
  end

  test "wizard step 3 without agregar_otro clears wizard session" do
    post cuenta_pre_alertas_url, params: { wizard_step: 1, tipo_envio_id: tipo_envios(:cer).id }
    post cuenta_pre_alertas_url, params: { wizard_step: 2, consolidado: "0" }

    assert_difference("PreAlerta.count", 1) do
      post cuenta_pre_alertas_url, params: {
        wizard_step: 3,
        titulo: "Laptop",
        tracking: "NOSESSION001",
        descripcion: "MacBook Pro"
      }
    end

    pa = PreAlerta.last
    assert_redirected_to cuenta_root_url
    assert_match "registrada", flash[:success_modal]
    assert pa.notificado?

    follow_redirect!
    assert_nil session[:pre_alerta_wizard]
  end

  test "wizard step 3 fails without tracking" do
    post cuenta_pre_alertas_url, params: { wizard_step: 1, tipo_envio_id: tipo_envios(:cer).id }
    post cuenta_pre_alertas_url, params: { wizard_step: 2, consolidado: "0" }

    assert_no_difference("PreAlerta.count") do
      post cuenta_pre_alertas_url, params: {
        wizard_step: 3,
        titulo: "Zapatos",
        tracking: "",
        descripcion: "Zapatos Nike"
      }
    end

    assert_response :unprocessable_entity
  end

  test "wizard step 3 persists instrucciones field" do
    post cuenta_pre_alertas_url, params: { wizard_step: 1, tipo_envio_id: tipo_envios(:cer).id }
    post cuenta_pre_alertas_url, params: { wizard_step: 2, consolidado: "0" }

    assert_difference("PreAlertaPaquete.count", 1) do
      post cuenta_pre_alertas_url, params: {
        wizard_step: 3,
        titulo: "Con instrucciones",
        tracking: "INSTRTEST001",
        descripcion: "Con instrucciones",
        instrucciones: "Combinar con otro paquete",
        valor_declarado: "25.00",
        peso: "1.5"
      }
    end

    pap = PreAlertaPaquete.last
    assert_equal "Combinar con otro paquete", pap.instrucciones
  end

  test "wizard step 3 save failure preserves instrucciones in re-render" do
    TipoEnvio.where(codigo: "cer").destroy_all

    post cuenta_pre_alertas_url, params: {
      wizard_step: 3,
      tracking: "FAILINSTR001",
      descripcion: "Test",
      instrucciones: "Manejar con cuidado"
    }

    assert_response :unprocessable_entity
    assert_match "Manejar con cuidado", response.body
  end

  # Edit
  test "should get edit" do
    get edit_cuenta_pre_alerta_url(@pre_alerta)
    assert_response :success
  end

  # Update
  test "should update pre_alerta with paquetes" do
    patch cuenta_pre_alerta_url(@pre_alerta), params: {
      pre_alerta: {
        notas_grupo: "Updated notes",
        pre_alerta_paquetes_attributes: {
          "0" => { tracking: "NEWTRACK999", descripcion: "New package" }
        }
      }
    }
    assert_redirected_to edit_cuenta_pre_alerta_url(@pre_alerta)
    assert_equal "Updated notes", @pre_alerta.reload.notas_grupo
  end

  test "should update paquete instrucciones" do
    pap = pre_alerta_paquetes(:pap_sin_vincular)
    patch cuenta_pre_alerta_url(@pre_alerta), params: {
      pre_alerta: {
        pre_alerta_paquetes_attributes: {
          "0" => { id: pap.id, instrucciones: "No abrir" }
        }
      }
    }
    assert_redirected_to edit_cuenta_pre_alerta_url(@pre_alerta)
    assert_equal "No abrir", pap.reload.instrucciones
  end

  test "should update via turbo_stream" do
    patch cuenta_pre_alerta_url(@pre_alerta), params: {
      pre_alerta: { notas_grupo: "Turbo update" }
    }, as: :turbo_stream
    assert_response :success
  end

  test "should set notificado when notificar param present" do
    patch cuenta_pre_alerta_url(@pre_alerta), params: {
      notificar: "true",
      pre_alerta: { notas_grupo: "Notify test" }
    }
    assert @pre_alerta.reload.notificado?
  end

  # Anular
  test "should anular pre_alerta" do
    delete anular_cuenta_pre_alerta_url(@pre_alerta)
    assert_redirected_to cuenta_pre_alertas_url
    assert_equal "anulado", @pre_alerta.reload.estado
  end

  # Security
  test "requires authentication" do
    delete session_url
    get cuenta_pre_alertas_url
    assert_redirected_to new_session_url
  end

  # ── v4 services ──
  test "step 1 shows all v4 canonical services in both groups" do
    get new_cuenta_pre_alerta_url
    assert_response :success
    # Left group (con reempaque + consolidable)
    assert_match "EXPRESS", response.body
    assert_match "CER", response.body
    assert_match "CEM", response.body
    # Right group (sin reempaque, sin consolidar)
    assert_match "CKA", response.body
    assert_match "CKM", response.body
  end

  test "wizard step 3 creates with CKA (single package service) skipping step 2" do
    cka = tipo_envios(:cka)
    post cuenta_pre_alertas_url, params: { wizard_step: 1, tipo_envio_id: cka.id }
    assert_redirected_to new_cuenta_pre_alerta_url(step: 3)

    assert_difference("PreAlerta.count") do
      post cuenta_pre_alertas_url, params: {
        wizard_step: 3,
        titulo: "Caja CKA",
        tracking: "CKAWIZ001",
        descripcion: "Paquete CKA"
      }
    end

    pa = PreAlerta.last
    assert_equal cka, pa.tipo_envio
    assert_not pa.consolidado?
    # Sin reempaque → redirect to home, not edit
    assert_redirected_to cuenta_root_url
  end

  test "wizard step 3 creates with CKM and redirects to home" do
    ckm = tipo_envios(:ckm)
    post cuenta_pre_alertas_url, params: { wizard_step: 1, tipo_envio_id: ckm.id }
    assert_redirected_to new_cuenta_pre_alerta_url(step: 3)

    assert_difference("PreAlerta.count") do
      post cuenta_pre_alertas_url, params: {
        wizard_step: 3,
        titulo: "Caja CKM",
        tracking: "CKMWIZ001",
        descripcion: "Paquete CKM"
      }
    end

    pa = PreAlerta.last
    assert_equal ckm, pa.tipo_envio
    assert_not pa.consolidado?
    assert_redirected_to cuenta_root_url
    assert_match "registrada exitosamente", flash[:success_modal]
  end

  test "wizard step 3 with con reempaque sin consolidar redirects to home" do
    post cuenta_pre_alertas_url, params: { wizard_step: 1, tipo_envio_id: tipo_envios(:express).id }
    post cuenta_pre_alertas_url, params: { wizard_step: 2, consolidado: "0" }

    assert_difference("PreAlerta.count") do
      post cuenta_pre_alertas_url, params: {
        wizard_step: 3,
        titulo: "Monitor",
        tracking: "EXPRESSWIZ001",
        descripcion: "Monitor Dell"
      }
    end

    pa = PreAlerta.last
    assert_redirected_to cuenta_root_url
    assert_match "registrada", flash[:success_modal]
    assert pa.notificado?
  end

  # ── Finalization ──
  test "finalizar sets finalizado to true" do
    pa = pre_alertas(:consolidada_destino)
    assert_not pa.finalizado?

    patch cuenta_pre_alerta_url(pa), params: {
      notificar: "true",
      finalizar: "true",
      pre_alerta: { notas_grupo: "Final notes" }
    }
    assert_redirected_to cuenta_root_url
    assert pa.reload.finalizado?
    assert pa.notificado?
  end

  test "update rejected on finalized PA" do
    pa = pre_alertas(:finalizada)
    patch cuenta_pre_alerta_url(pa), params: {
      pre_alerta: { titulo: "Should not change" }
    }
    assert_redirected_to edit_cuenta_pre_alerta_url(pa)
    assert_equal "Compra Black Friday", pa.reload.titulo
  end

  test "mover blocked from finalized PA" do
    pa = pre_alertas(:finalizada)
    pap = pre_alerta_paquetes(:pap_finalizada)
    destino = pre_alertas(:consolidada_destino)

    post mover_paquete_cuenta_pre_alerta_url(pa), params: {
      pre_alerta_paquete_id: pap.id,
      destino_id: destino.id
    }
    assert_redirected_to edit_cuenta_pre_alerta_url(pa)
    assert_match "finalizada", flash[:alert]
    assert_equal pa.id, pap.reload.pre_alerta_id
  end

  test "destinos excludes finalized PAs" do
    pa = pre_alertas(:consolidada_destino)
    pap = pre_alerta_paquetes(:pap_destino)

    get destinos_disponibles_cuenta_pre_alerta_url(pa, pre_alerta_paquete_id: pap.id), as: :json
    assert_response :success

    destino_ids = response.parsed_body.map { |d| d["id"] }
    finalizada = pre_alertas(:finalizada)
    assert_not_includes destino_ids, finalizada.id
  end

  test "eliminar blocked on finalized PA" do
    pa = pre_alertas(:finalizada)
    pap = pre_alerta_paquetes(:pap_finalizada)

    assert_no_difference("PreAlertaPaquete.count") do
      delete eliminar_paquete_cuenta_pre_alerta_url(pa, pre_alerta_paquete_id: pap.id)
    end
    assert_redirected_to edit_cuenta_pre_alerta_url(pa)
    assert_match "finalizada", flash[:alert]
  end

  test "move writes to historial not notas_grupo" do
    pa = pre_alertas(:recibida)
    pap = pre_alerta_paquetes(:pap_vinculado)
    destino = pre_alertas(:consolidada_destino)

    # Ensure notas_grupo starts empty
    pa.update_column(:notas_grupo, nil)
    destino.update_column(:notas_grupo, nil)

    post mover_paquete_cuenta_pre_alerta_url(pa), params: {
      pre_alerta_paquete_id: pap.id,
      destino_id: destino.id
    }

    pa.reload
    destino.reload
    # notas_grupo should stay nil — moves go to historial now
    assert_nil pa.notas_grupo
    assert_nil destino.notas_grupo
    assert pa.historial.present?
    assert_match "movido a", pa.historial
    assert destino.historial.present?
    assert_match "recibido de", destino.historial
  end

  # ── CKA/CKM move blocking ──
  test "should not allow moving unlinked paquete from CKA PA" do
    pa = pre_alertas(:cka_pa)
    pap = pre_alerta_paquetes(:pap_cka_unlinked)
    destino = pre_alertas(:consolidada_destino)

    post mover_paquete_cuenta_pre_alerta_url(pa), params: {
      pre_alerta_paquete_id: pap.id,
      destino_id: destino.id
    }
    assert_redirected_to edit_cuenta_pre_alerta_url(pa)
    assert_match "No se puede mover", flash[:alert]
    assert_equal pa.id, pap.reload.pre_alerta_id
  end

  test "destinos returns empty for CKA PA" do
    pa = pre_alertas(:cka_pa)
    pap = pre_alerta_paquetes(:pap_cka_unlinked)

    get destinos_disponibles_cuenta_pre_alerta_url(pa, pre_alerta_paquete_id: pap.id), as: :json
    assert_response :success
    assert_equal [], response.parsed_body
  end

  # ── Autosave ──
  test "autosave returns JSON on success" do
    pa = pre_alertas(:consolidada_destino)
    patch cuenta_pre_alerta_url(pa), params: {
      autosave: "true",
      pre_alerta: { titulo: "Autosaved title" }
    }, as: :json
    assert_response :success
    body = response.parsed_body
    assert_equal "saved", body["status"]
    assert_equal "Autosaved title", pa.reload.titulo
  end

  test "autosave creates new paquete and returns its id" do
    pa = pre_alertas(:consolidada_destino)
    assert_difference("PreAlertaPaquete.count", 1) do
      patch cuenta_pre_alerta_url(pa), params: {
        autosave: "true",
        pre_alerta: {
          pre_alerta_paquetes_attributes: {
            "99999" => { tracking: "AUTOSAVETRACK001", descripcion: "Autosaved pkg" }
          }
        }
      }, as: :json
    end
    assert_response :success
    body = response.parsed_body
    assert_equal "saved", body["status"]
    assert body["new_paquetes"]["99999"].present?
    pap = PreAlertaPaquete.find(body["new_paquetes"]["99999"])
    assert_equal "AUTOSAVETRACK001", pap.tracking
  end

  test "autosave returns 422 on validation error" do
    pa = pre_alertas(:consolidada_destino)
    # tracking with invalid characters passes reject_if but fails format validation
    patch cuenta_pre_alerta_url(pa), params: {
      autosave: "true",
      pre_alerta: {
        pre_alerta_paquetes_attributes: {
          "0" => { tracking: "INVALID SPACES", descripcion: "Test" }
        }
      }
    }, as: :json
    assert_response :unprocessable_entity
    body = response.parsed_body
    assert_equal "error", body["status"]
    assert body["errors"].any?
  end

  test "autosave rejected on finalized PA" do
    pa = pre_alertas(:finalizada)
    patch cuenta_pre_alerta_url(pa), params: {
      autosave: "true",
      pre_alerta: { titulo: "Should not change" }
    }, as: :json
    assert_response :unprocessable_entity
    body = response.parsed_body
    assert_equal "error", body["status"]
    assert_equal "Compra Black Friday", pa.reload.titulo
  end

  test "autosave deletes paquete marked with _destroy" do
    pa = pre_alertas(:consolidada_destino)
    pap = pre_alerta_paquetes(:pap_destino)
    assert_difference("PreAlertaPaquete.count", -1) do
      patch cuenta_pre_alerta_url(pa), params: {
        autosave: "true",
        pre_alerta: {
          pre_alerta_paquetes_attributes: {
            "0" => { id: pap.id, _destroy: "1" }
          }
        }
      }, as: :json
    end
    assert_response :success
    assert_equal "saved", response.parsed_body["status"]
  end

  # ── v4: step-3 save-failure re-renders step 3, not step 1 ──
  # Regression guard: new.html.erb reads params[:step] to decide which step to
  # render, but render :new after a failed step-3 POST only has params[:wizard_step].
  # Without a fallback, the view silently bounced the user back to step 1,
  # losing their input and hiding error messages.
  test "wizard step 3 save failure re-renders step 3 with errors and preserved input" do
    # Force save failure: remove CER so assign_default_tipo_envio has no fallback,
    # and skip wizard steps 1/2 so the session has no tipo_envio_id.
    TipoEnvio.where(codigo: "cer").destroy_all

    assert_no_difference("PreAlerta.count") do
      post cuenta_pre_alertas_url, params: {
        wizard_step: 3,
        titulo: "TV Samsung",
        proveedor: "Amazon",
        tracking: "FAIL001",
        descripcion: "Paquete con error"
      }
    end

    assert_response :unprocessable_entity

    # Must land on step 3, not step 1. Step-3-only copy:
    assert_match "Datos del paquete", response.body
    # Step-1-only copy must NOT appear:
    assert_no_match(/Elige tu servicio/, response.body)

    # User input preserved via params echo
    assert_match "FAIL001", response.body
    assert_match "Paquete con error", response.body
    assert_match "TV Samsung", response.body
    assert_match "Amazon", response.body
  end
end
