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

  test "should get new step 2" do
    get new_cuenta_pre_alerta_url(step: 2)
    assert_response :success
  end

  test "should get new step 3" do
    get new_cuenta_pre_alerta_url(step: 3)
    assert_response :success
  end

  # Create via wizard
  test "wizard step 1 stores reempaque in session" do
    post cuenta_pre_alertas_url, params: { wizard_step: 1, con_reempaque: "1" }
    assert_redirected_to new_cuenta_pre_alerta_url(step: 2)
  end

  test "wizard step 2 stores consolidado in session" do
    post cuenta_pre_alertas_url, params: { wizard_step: 2, consolidado: "1" }
    assert_redirected_to new_cuenta_pre_alerta_url(step: 3)
  end

  test "wizard step 3 creates pre_alerta" do
    # Setup wizard session
    post cuenta_pre_alertas_url, params: { wizard_step: 1, con_reempaque: "1" }
    post cuenta_pre_alertas_url, params: { wizard_step: 2, consolidado: "0" }

    assert_difference("PreAlerta.count") do
      post cuenta_pre_alertas_url, params: { wizard_step: 3, tipo_envio_id: tipo_envios(:aereo).id }
    end

    pa = PreAlerta.last
    assert_redirected_to edit_cuenta_pre_alerta_url(pa)
    assert pa.con_reempaque?
    assert_not pa.consolidado?
    assert_equal "cliente", pa.creado_por_tipo
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
end
