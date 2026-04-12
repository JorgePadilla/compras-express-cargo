require "test_helper"

class RecibosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:cajero)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @recibo = recibos(:recibo_maria)
  end

  test "should get index" do
    get recibos_url
    assert_response :success
  end

  test "should show recibo" do
    get recibo_url(@recibo)
    assert_response :success
  end

  test "digitador cannot access recibos" do
    delete session_url
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }
    get recibos_url
    assert_redirected_to root_url
  end
end
