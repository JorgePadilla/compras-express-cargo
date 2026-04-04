require "test_helper"

class Cuenta::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cliente = clientes(:juan)
  end

  test "should get new" do
    get new_cuenta_session_url
    assert_response :success
  end

  test "should login with valid credentials" do
    post cuenta_session_url, params: { email: @cliente.email, password: "Cliente123!" }
    assert_redirected_to cuenta_root_url
  end

  test "should not login with invalid password" do
    post cuenta_session_url, params: { email: @cliente.email, password: "wrong" }
    assert_redirected_to new_cuenta_session_url
    follow_redirect!
    assert_response :success
  end

  test "should not login with non-existent email" do
    post cuenta_session_url, params: { email: "nobody@test.com", password: "Cliente123!" }
    assert_redirected_to new_cuenta_session_url
  end

  test "should not login inactive client" do
    inactivo = clientes(:inactivo)
    post cuenta_session_url, params: { email: inactivo.email, password: "Cliente123!" }
    assert_redirected_to new_cuenta_session_url
  end

  test "should logout" do
    post cuenta_session_url, params: { email: @cliente.email, password: "Cliente123!" }
    delete cuenta_session_url
    assert_redirected_to new_cuenta_session_url
  end

  test "should redirect to login when not authenticated" do
    get cuenta_root_url
    assert_redirected_to new_cuenta_session_url
  end
end
