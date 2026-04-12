require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user    = users(:admin)
    @cliente = clientes(:juan)
  end

  test "should get new" do
    get new_session_url
    assert_response :success
  end

  # ── Employee (User) login ──
  test "should login employee with valid credentials" do
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    assert_redirected_to root_url
  end

  test "should not login employee with invalid password" do
    post session_url, params: { email_address: @user.email_address, password: "wrong" }
    assert_redirected_to new_session_url
  end

  test "should logout employee" do
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    delete session_url
    assert_redirected_to new_session_url
  end

  # ── Cliente login (unified) ──
  test "should login cliente with valid credentials" do
    post session_url, params: { email_address: @cliente.email, password: "Cliente123!" }
    assert_redirected_to cuenta_root_url
  end

  test "should not login cliente with invalid password" do
    post session_url, params: { email_address: @cliente.email, password: "wrong" }
    assert_redirected_to new_session_url
    follow_redirect!
    assert_response :success
  end

  test "should not login with non-existent email" do
    post session_url, params: { email_address: "nobody@test.com", password: "Cliente123!" }
    assert_redirected_to new_session_url
  end

  test "should not login inactive cliente" do
    inactivo = clientes(:inactivo)
    post session_url, params: { email_address: inactivo.email, password: "Cliente123!" }
    assert_redirected_to new_session_url
  end

  test "should logout cliente" do
    post session_url, params: { email_address: @cliente.email, password: "Cliente123!" }
    delete session_url
    assert_redirected_to new_session_url
  end

  test "should redirect cliente to login when not authenticated" do
    get cuenta_root_url
    assert_redirected_to new_session_url
  end

  test "cliente login honors return_to after deep link" do
    get cuenta_pre_alertas_url
    assert_redirected_to new_session_url

    post session_url, params: { email_address: @cliente.email, password: "Cliente123!" }
    assert_redirected_to cuenta_pre_alertas_url
  end
end
