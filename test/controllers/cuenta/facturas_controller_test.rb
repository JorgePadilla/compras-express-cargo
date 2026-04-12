require "test_helper"

class Cuenta::FacturasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cliente = clientes(:juan)
    post session_url, params: { email_address: @cliente.email, password: "Cliente123!" }
    @venta = ventas(:pendiente_juan)
  end

  test "should get index" do
    get cuenta_facturas_url
    assert_response :success
  end

  test "index filters by estado" do
    get cuenta_facturas_url, params: { estado: "pendiente" }
    assert_response :success
  end

  test "should show venta" do
    get cuenta_factura_url(@venta)
    assert_response :success
  end

  test "should not show another clients venta" do
    other = ventas(:pagada_maria)
    get cuenta_factura_url(other)
    assert_response :not_found
  end

  test "pdf responds with application/pdf" do
    get pdf_cuenta_factura_url(@venta)
    assert_response :success
    assert_equal "application/pdf", response.content_type
  end
end
