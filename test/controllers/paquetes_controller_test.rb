require "test_helper"

class PaquetesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @paquete = paquetes(:recibido)
  end

  test "should get index" do
    get paquetes_url
    assert_response :success
  end

  test "should search paquetes" do
    get paquetes_url, params: { q: "1Z999" }
    assert_response :success
  end

  test "should filter by estado" do
    get paquetes_url, params: { estado: "recibido" }
    assert_response :success
  end

  test "should show paquete" do
    get paquete_url(@paquete)
    assert_response :success
  end

  test "should get edit" do
    get edit_paquete_url(@paquete)
    assert_response :success
  end

  test "should update paquete" do
    patch paquete_url(@paquete), params: { paquete: { descripcion: "Updated" } }
    assert_redirected_to paquete_url(@paquete)
    @paquete.reload
    assert_equal "Updated", @paquete.descripcion
  end

  test "should get label" do
    get label_paquete_url(@paquete)
    assert_response :success
  end

  test "should check tracking" do
    get check_tracking_paquetes_url, params: { tracking: @paquete.tracking }
    assert_response :success
    json = JSON.parse(response.body)
    assert json["exists"]
    assert_equal @paquete.guia, json["guia"]
  end

  test "should check tracking not found" do
    get check_tracking_paquetes_url, params: { tracking: "NONEXISTENT" }
    assert_response :success
    json = JSON.parse(response.body)
    assert_not json["exists"]
  end

  test "should search unassigned paquetes" do
    get search_paquetes_url, params: { q: "PQ-000" }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
  end
end
