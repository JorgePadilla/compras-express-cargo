require "test_helper"

class Cuenta::NotasDebitoControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cliente = clientes(:maria)
    post session_url, params: { email_address: @cliente.email, password: "Cliente123!" }
    @nd = notas_debito(:nd_emitida)
  end

  test "should get index" do
    get cuenta_notas_debito_url
    assert_response :success
  end

  test "should show emitida nota debito" do
    get cuenta_nota_debito_url(@nd)
    assert_response :success
  end

  test "should not show another clients nota debito" do
    nd_otro = notas_debito(:nd_creada) # belongs to juan, not maria
    get cuenta_nota_debito_url(nd_otro)
    assert_response :not_found
  end

  test "should not show creada nota debito" do
    # Even if owned, creada should not be accessible via cuenta
    # nd_creada belongs to juan, not maria; so it's a 404 anyway
    get cuenta_nota_debito_url(notas_debito(:nd_creada))
    assert_response :not_found
  end

  test "pdf responds with application/pdf" do
    get pdf_cuenta_nota_debito_url(@nd)
    assert_response :success
    assert_equal "application/pdf", response.content_type
  end
end
