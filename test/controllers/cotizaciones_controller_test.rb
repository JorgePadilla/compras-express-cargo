require "test_helper"

class CotizacionesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:cajero)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @cotizacion = cotizaciones(:borrador_juan)
  end

  test "should get index" do
    get cotizaciones_url
    assert_response :success
  end

  test "should get new" do
    get new_cotizacion_url
    assert_response :success
  end

  test "should create cotizacion" do
    assert_difference "Cotizacion.count", 1 do
      post cotizaciones_url, params: {
        cotizacion: {
          cliente_id: clientes(:juan).id,
          moneda: "LPS",
          vigencia_dias: 30,
          cotizacion_items_attributes: {
            "0" => { concepto: "Flete test", peso_cobrar: 5, precio_libra: 4, subtotal: 20 }
          }
        }
      }
    end
    assert_redirected_to cotizacion_url(Cotizacion.last)
  end

  test "should show cotizacion" do
    get cotizacion_url(@cotizacion)
    assert_response :success
  end

  test "should get edit for borrador" do
    get edit_cotizacion_url(@cotizacion)
    assert_response :success
  end

  test "enviar transitions to enviada" do
    post enviar_cotizacion_url(@cotizacion)
    assert @cotizacion.reload.enviada?
    assert_redirected_to cotizacion_url(@cotizacion)
  end

  test "aceptar transitions enviada to aceptada" do
    ct = cotizaciones(:enviada_maria)
    post aceptar_cotizacion_url(ct)
    assert ct.reload.aceptada?
  end

  test "rechazar transitions enviada to rechazada" do
    ct = cotizaciones(:enviada_maria)
    delete rechazar_cotizacion_url(ct)
    assert ct.reload.rechazada?
  end

  test "generar_proforma creates venta" do
    ct = cotizaciones(:aceptada_juan)
    assert_difference "Venta.count", 1 do
      post generar_proforma_cotizacion_url(ct)
    end
    assert_redirected_to proforma_url(ct.reload.venta)
  end

  test "pdf responds with application/pdf" do
    get pdf_cotizacion_url(@cotizacion)
    assert_response :success
    assert_equal "application/pdf", response.content_type
  end

  test "digitador cannot access cotizaciones" do
    delete session_url
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }
    get cotizaciones_url
    assert_redirected_to root_url
  end
end
