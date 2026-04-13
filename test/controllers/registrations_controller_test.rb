require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new registration form" do
    get new_registro_url
    assert_response :success
  end

  test "should create client account" do
    assert_difference("Cliente.count") do
      post registro_url, params: { cliente: {
        nombre: "Test", apellido: "User",
        email: "newclient@test.com", telefono: "99990000",
        password: "Secure123!", password_confirmation: "Secure123!"
      } }
    end
    assert_redirected_to cuenta_root_path
    follow_redirect!
    assert_response :success

    cliente = Cliente.find_by(email: "newclient@test.com")
    assert cliente.activo?
    assert cliente.codigo.present?
  end

  test "should not create client with missing fields" do
    assert_no_difference("Cliente.count") do
      post registro_url, params: { cliente: {
        nombre: "", apellido: "",
        email: "", telefono: "",
        password: "", password_confirmation: ""
      } }
    end
    assert_response :unprocessable_entity
  end

  test "should not create client with short password" do
    assert_no_difference("Cliente.count") do
      post registro_url, params: { cliente: {
        nombre: "Test", apellido: "User",
        email: "short@test.com", telefono: "99990000",
        password: "short", password_confirmation: "short"
      } }
    end
    assert_response :unprocessable_entity
  end

  test "should not create client with mismatched password" do
    assert_no_difference("Cliente.count") do
      post registro_url, params: { cliente: {
        nombre: "Test", apellido: "User",
        email: "mismatch@test.com", telefono: "99990000",
        password: "Secure123!", password_confirmation: "Different456!"
      } }
    end
    assert_response :unprocessable_entity
  end

  test "should not create client with duplicate email" do
    existing = clientes(:juan)
    assert_no_difference("Cliente.count") do
      post registro_url, params: { cliente: {
        nombre: "Duplicate", apellido: "Email",
        email: existing.email, telefono: "99990000",
        password: "Secure123!", password_confirmation: "Secure123!"
      } }
    end
    assert_response :unprocessable_entity
  end

  test "should auto-generate codigo" do
    post registro_url, params: { cliente: {
      nombre: "Auto", apellido: "Code",
      email: "autocode@test.com", telefono: "99990000",
      password: "Secure123!", password_confirmation: "Secure123!"
    } }
    cliente = Cliente.find_by(email: "autocode@test.com")
    assert_match(/\ACEC-\d{3,}\z/, cliente.codigo)
  end

  test "login page should have registration link" do
    get new_session_url
    assert_response :success
    assert_select "a[href=?]", new_registro_path
  end
end
