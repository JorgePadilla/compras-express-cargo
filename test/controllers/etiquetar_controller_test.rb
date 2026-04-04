require "test_helper"

class EtiquetarControllerTest < ActionDispatch::IntegrationTest
  setup do
    @digitador = users(:digitador)
    post session_url, params: { email_address: @digitador.email_address, password: "password123" }
  end

  test "should get index" do
    get etiquetar_url
    assert_response :success
  end

  test "should create paquete" do
    assert_difference("Paquete.count") do
      post etiquetar_url, params: { paquete: {
        tracking: "1Z999NEWTRACK001",
        cliente_id: clientes(:juan).id,
        tipo_envio_id: tipo_envios(:aereo).id,
        peso: 5.0,
        descripcion: "Test package"
      } }
    end
    paquete = Paquete.last
    assert_equal "etiquetado", paquete.estado
    assert_equal @digitador, paquete.user
    assert_redirected_to etiquetar_url
  end

  test "should not create paquete without tracking" do
    assert_no_difference("Paquete.count") do
      post etiquetar_url, params: { paquete: {
        tracking: "",
        cliente_id: clientes(:juan).id
      } }
    end
    assert_response :unprocessable_entity
  end

  test "should not create paquete without client" do
    assert_no_difference("Paquete.count") do
      post etiquetar_url, params: { paquete: {
        tracking: "1Z999NOCLIENT001"
      } }
    end
    assert_response :unprocessable_entity
  end

  test "cajero cannot access etiquetar" do
    delete session_url
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }
    get etiquetar_url
    assert_redirected_to root_path
  end

  test "admin can access etiquetar" do
    delete session_url
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
    get etiquetar_url
    assert_response :success
  end
end
