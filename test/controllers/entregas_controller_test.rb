require "test_helper"

class EntregasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:repartidor)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @entrega = entregas(:pendiente_juan)
  end

  test "should get index" do
    get entregas_url
    assert_response :success
  end

  test "index filters by estado" do
    get entregas_url, params: { estado: "pendiente" }
    assert_response :success
  end

  test "should get new without cliente_id" do
    get new_entrega_url
    assert_response :success
  end

  test "should get new with cliente_id" do
    get new_entrega_url, params: { cliente_id: clientes(:juan).id }
    assert_response :success
  end

  test "should show entrega" do
    get entrega_url(@entrega)
    assert_response :success
  end

  test "should get edit for pendiente" do
    get edit_entrega_url(@entrega)
    assert_response :success
  end

  test "should create entrega" do
    assert_difference "Entrega.count", 1 do
      post entregas_url, params: {
        entrega: {
          cliente_id: clientes(:juan).id,
          tipo_entrega: "retiro_oficina",
          receptor_nombre: "Juan Perez",
          receptor_identidad: "0801199012345"
        },
        paquete_ids: [paquetes(:facturado_juan2).id]
      }
    end
    assert_redirected_to entrega_url(Entrega.last)
  end

  test "should update entrega" do
    patch entrega_url(@entrega), params: {
      entrega: { receptor_nombre: "Juan Carlos" }
    }
    assert_redirected_to entrega_url(@entrega)
    assert_equal "Juan Carlos", @entrega.reload.receptor_nombre
  end

  test "despachar transitions to en_reparto" do
    post despachar_entrega_url(@entrega)
    assert_equal "en_reparto", @entrega.reload.estado
    assert_redirected_to entrega_url(@entrega)
  end

  test "entregar transitions to entregado" do
    @entrega.despachar!
    post entregar_entrega_url(@entrega)
    assert_equal "entregado", @entrega.reload.estado
    assert_redirected_to entrega_url(@entrega)
  end

  test "anular returns paquetes to facturado" do
    delete anular_entrega_url(@entrega)
    assert_equal "anulado", @entrega.reload.estado
    assert_redirected_to entregas_url
  end

  test "entregables returns json" do
    get entregables_entregas_url, params: { cliente_id: clientes(:juan).id }
    assert_response :success
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
  end

  test "unauthorized user redirected" do
    delete session_url
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }
    get entregas_url
    assert_redirected_to root_url
  end
end
