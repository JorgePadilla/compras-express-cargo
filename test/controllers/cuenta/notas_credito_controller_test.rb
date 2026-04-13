require "test_helper"

class Cuenta::NotasCreditoControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cliente = clientes(:maria)
    post session_url, params: { email_address: @cliente.email, password: "Cliente123!" }
    @nc = notas_credito(:nc_emitida)
  end

  test "should get index" do
    get cuenta_notas_credito_url
    assert_response :success
  end

  test "should show emitida nota credito" do
    get cuenta_nota_credito_url(@nc)
    assert_response :success
  end

  test "should not show another clients nota credito" do
    nc_otro = notas_credito(:nc_creada) # belongs to juan
    get cuenta_nota_credito_url(nc_otro)
    assert_response :not_found
  end

  test "pdf responds with application/pdf" do
    get pdf_cuenta_nota_credito_url(@nc)
    assert_response :success
    assert_equal "application/pdf", response.content_type
  end
end
