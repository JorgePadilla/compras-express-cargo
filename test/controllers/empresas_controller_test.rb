require "test_helper"

class EmpresasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @empresa = Empresa.instance
  end

  test "should show empresa" do
    get empresa_url
    assert_response :success
  end

  test "should get edit" do
    get edit_empresa_url
    assert_response :success
  end

  test "should update empresa" do
    patch empresa_url, params: { empresa: { rtn: "99991234567890" } }
    assert_redirected_to empresa_url
    assert_equal "99991234567890", @empresa.reload.rtn
  end

  test "cajero cannot access empresa" do
    delete session_url
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }
    get empresa_url
    assert_redirected_to root_url
  end
end
