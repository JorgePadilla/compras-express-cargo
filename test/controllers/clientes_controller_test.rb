require "test_helper"

class ClientesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @cliente = clientes(:juan)
  end

  test "should get index" do
    get clientes_url
    assert_response :success
  end

  test "should search clientes" do
    get clientes_url, params: { q: "Juan" }
    assert_response :success
  end

  test "should get new" do
    get new_cliente_url
    assert_response :success
  end

  test "should create cliente" do
    assert_difference("Cliente.count") do
      post clientes_url, params: { cliente: {
        nombre: "Nuevo", apellido: "Cliente", email: "nuevo@test.com",
        telefono: "99998888", ciudad: "Tegucigalpa"
      } }
    end
    assert_redirected_to cliente_url(Cliente.last)
  end

  test "should not create invalid cliente" do
    assert_no_difference("Cliente.count") do
      post clientes_url, params: { cliente: { nombre: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "should show cliente" do
    get cliente_url(@cliente)
    assert_response :success
  end

  test "should get edit" do
    get edit_cliente_url(@cliente)
    assert_response :success
  end

  test "should update cliente" do
    patch cliente_url(@cliente), params: { cliente: { nombre: "Updated" } }
    assert_redirected_to cliente_url(@cliente)
    @cliente.reload
    assert_equal "Updated", @cliente.nombre
  end

  test "should not update with invalid data" do
    patch cliente_url(@cliente), params: { cliente: { nombre: "" } }
    assert_response :unprocessable_entity
  end

  test "admin can access buscar" do
    get buscar_clientes_url, params: { q: "CEC" }, as: :json
    assert_response :success
  end

  test "digitador can access buscar" do
    delete session_url
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }
    get buscar_clientes_url, params: { q: "CEC" }, as: :json
    assert_response :success
  end

  test "cajero can access buscar" do
    delete session_url
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }
    get buscar_clientes_url, params: { q: "CEC" }, as: :json
    assert_response :success
  end

  test "buscar returns html-escaped data" do
    get buscar_clientes_url, params: { q: "CEC" }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    json.each do |c|
      assert_not_includes c["nombre"].to_s, "<script"
      assert_not_includes c["codigo"].to_s, "<script"
    end
  end
end
