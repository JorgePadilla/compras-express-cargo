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

  # PR-F1.4 · La razón social se carga acá; el ISV ya no se edita.
  test "guarda la razón social y no toca el ISV" do
    patch empresa_url, params: { empresa: { razon_social: "Compras Express Cargo, S. de R.L.", isv_rate: 0.18 } }
    assert_redirected_to empresa_url
    assert_equal "Compras Express Cargo, S. de R.L.", @empresa.reload.razon_social
    assert_equal BigDecimal("0.15"), @empresa.isv_rate

    get edit_empresa_url
    assert_select "input[name='empresa[razon_social]']"
    assert_select "input[name='empresa[isv_rate]']", count: 0
    assert_match "15 % (Ley ISV)", response.body
  end

  test "cajero cannot access empresa" do
    delete session_url
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }
    get empresa_url
    assert_redirected_to root_url
  end
end
