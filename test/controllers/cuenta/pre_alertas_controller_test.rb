require "test_helper"

class Cuenta::PreAlertasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cliente = clientes(:juan)
    post cuenta_session_url, params: { email: @cliente.email, password: "Cliente123!" }
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
          tracking: "WIZTRACK001",
          descripcion: "Paquete desde wizard",
          valor_declarado: "49.99",
          peso: "5.5"
        }
      end
    end

    pa = PreAlerta.last
    assert_redirected_to edit_cuenta_pre_alerta_url(pa)
    assert_equal tipo_envios(:cer), pa.tipo_envio
    assert pa.con_reempaque?
    assert_not pa.consolidado?
    assert_equal "cliente", pa.creado_por_tipo

    pap = pa.pre_alerta_paquetes.first
    assert_equal "WIZTRACK001", pap.tracking
    assert_equal "Paquete desde wizard", pap.descripcion
    assert_equal BigDecimal("49.99"), pap.valor_declarado
    assert_equal BigDecimal("5.5"), pap.peso
  end

  test "wizard step 3 creates pre_alerta with only peso (no tracking)" do
    post cuenta_pre_alertas_url, params: { wizard_step: 1, tipo_envio_id: tipo_envios(:cer).id }
    post cuenta_pre_alertas_url, params: { wizard_step: 2, consolidado: "0" }

    assert_difference("PreAlerta.count", 1) do
      post cuenta_pre_alertas_url, params: {
        wizard_step: 3,
        tracking: "",
        descripcion: "",
        valor_declarado: "",
        peso: "2.0"
      }
    end

    pa = PreAlerta.last
    assert_equal 1, pa.pre_alerta_paquetes.count
    assert_equal BigDecimal("2.0"), pa.pre_alerta_paquetes.first.peso
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
    delete cuenta_session_url
    get cuenta_pre_alertas_url
    assert_redirected_to new_cuenta_session_url
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
        tracking: "CKAWIZ001",
        descripcion: "Paquete CKA"
      }
    end

    pa = PreAlerta.last
    assert_equal cka, pa.tipo_envio
    assert_not pa.consolidado?
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
        tracking: "FAIL001",
        descripcion: "Paquete con error",
        valor_declarado: "12.50",
        peso: "3.25"
      }
    end

    assert_response :unprocessable_entity

    # Must land on step 3, not step 1. Step-3-only copy:
    assert_match "Datos del paquete", response.body
    # Step-1-only copy must NOT appear:
    assert_no_match(/Elige tu servicio/, response.body)

    # User input preserved via params echo at new.html.erb:280-309
    assert_match "FAIL001", response.body
    assert_match "Paquete con error", response.body
    assert_match "12.50", response.body
    assert_match "3.25", response.body
  end
end
