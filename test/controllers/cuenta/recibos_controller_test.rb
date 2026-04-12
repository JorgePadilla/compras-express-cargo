require "test_helper"

class Cuenta::RecibosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cliente = clientes(:maria)
    post session_url, params: { email_address: @cliente.email, password: "Cliente123!" }
    @recibo = recibos(:recibo_maria)
  end

  test "should get index" do
    get cuenta_recibos_url
    assert_response :success
  end

  test "should show recibo" do
    get cuenta_recibo_url(@recibo)
    assert_response :success
  end

  test "should not show another clients recibo" do
    # Login as juan instead
    delete session_url
    post session_url, params: { email_address: clientes(:juan).email, password: "Cliente123!" }
    get cuenta_recibo_url(@recibo)
    assert_response :not_found
  end
end
