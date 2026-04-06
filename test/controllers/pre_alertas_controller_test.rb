require "test_helper"

class PreAlertasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    post session_url, params: { email_address: @admin.email_address, password: "password123" }
    @pre_alerta = pre_alertas(:activa)
  end

  # Index
  test "should get index" do
    get pre_alertas_url
    assert_response :success
  end

  test "should filter by estado" do
    get pre_alertas_url, params: { estado: "pre_alerta" }
    assert_response :success
  end

  test "should filter by search term" do
    get pre_alertas_url, params: { q: "PA-000001" }
    assert_response :success
  end

  test "should filter by tipo_envio" do
    get pre_alertas_url, params: { tipo_envio_id: tipo_envios(:aereo).id }
    assert_response :success
  end

  test "should filter consolidados" do
    get pre_alertas_url, params: { solo_consolidados: "1" }
    assert_response :success
  end

  # Show
  test "should show pre_alerta" do
    get pre_alerta_url(@pre_alerta)
    assert_response :success
  end

  # New / Create
  test "should get new" do
    get new_pre_alerta_url
    assert_response :success
  end

  test "should create pre_alerta" do
    assert_difference("PreAlerta.count") do
      post pre_alertas_url, params: { pre_alerta: {
        cliente_id: clientes(:juan).id,
        tipo_envio_id: tipo_envios(:aereo).id,
        consolidado: false,
        con_reempaque: false,
        pre_alerta_paquetes_attributes: {
          "0" => { tracking: "1Z999NEWADMIN001", descripcion: "Test" }
        }
      } }
    end

    pa = PreAlerta.last
    assert_equal "usuario", pa.creado_por_tipo
    assert_redirected_to pre_alerta_path(pa)
  end

  test "should create pre_alerta with instrucciones" do
    assert_difference("PreAlerta.count") do
      post pre_alertas_url, params: { pre_alerta: {
        cliente_id: clientes(:juan).id,
        tipo_envio_id: tipo_envios(:aereo).id,
        pre_alerta_paquetes_attributes: {
          "0" => { tracking: "ADMININSTR001", descripcion: "Test", instrucciones: "Fragil" }
        }
      } }
    end

    pap = PreAlerta.last.pre_alerta_paquetes.first
    assert_equal "Fragil", pap.instrucciones
  end

  test "should not create pre_alerta without cliente" do
    assert_no_difference("PreAlerta.count") do
      post pre_alertas_url, params: { pre_alerta: {
        tipo_envio_id: tipo_envios(:aereo).id
      } }
    end
    assert_response :unprocessable_entity
  end

  # Edit / Update
  test "should get edit" do
    get edit_pre_alerta_url(@pre_alerta)
    assert_response :success
  end

  test "should update pre_alerta" do
    patch pre_alerta_url(@pre_alerta), params: { pre_alerta: { notas_grupo: "Updated notes" } }
    assert_redirected_to pre_alerta_path(@pre_alerta)
    assert_equal "Updated notes", @pre_alerta.reload.notas_grupo
  end

  test "should update paquete instrucciones" do
    pap = pre_alerta_paquetes(:pap_sin_vincular)
    patch pre_alerta_url(@pre_alerta), params: {
      pre_alerta: {
        pre_alerta_paquetes_attributes: {
          "0" => { id: pap.id, instrucciones: "Consolidar con PA-000002" }
        }
      }
    }
    assert_redirected_to pre_alerta_path(@pre_alerta)
    assert_equal "Consolidar con PA-000002", pap.reload.instrucciones
  end

  test "should update pre_alerta estado" do
    patch pre_alerta_url(@pre_alerta), params: { pre_alerta: { estado: "recibido" } }
    assert_redirected_to pre_alerta_path(@pre_alerta)
    assert_equal "recibido", @pre_alerta.reload.estado
  end

  # Anular
  test "should anular pre_alerta" do
    delete anular_pre_alerta_url(@pre_alerta)
    assert_redirected_to pre_alertas_path
    assert_equal "anulado", @pre_alerta.reload.estado
  end

  # Clean empty
  test "should clean empty pre_alertas" do
    # Create an old empty pre-alerta
    old_empty = PreAlerta.create!(
      cliente: clientes(:juan),
      tipo_envio: tipo_envios(:aereo),
      estado: "pre_alerta",
      created_at: 31.days.ago
    )

    post clean_empty_pre_alertas_url
    assert_redirected_to pre_alertas_path
    assert_not_nil old_empty.reload.deleted_at
  end

  # Role access
  test "all roles can access pre_alertas index" do
    delete session_url
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }
    get pre_alertas_url
    assert_response :success
  end

  test "digitador can access pre_alertas" do
    delete session_url
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }
    get pre_alertas_url
    assert_response :success
  end
end
