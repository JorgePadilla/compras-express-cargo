require "test_helper"

# PR-10.a: "la tabla de servicios" que Yusef pedía. Antes los precios se
# sembraban a mano y no había pantalla para tocarlos.
class ServiciosControllerTest < ActionDispatch::IntegrationTest
  setup { login_as users(:admin) }

  def login_as(user)
    delete session_url
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  test "index agrupa las tarifas por servicio" do
    get servicios_url

    assert_response :success
    assert_match "Tabla de Servicios", response.body
    assert_match "CER", response.body
  end

  test "crea una tarifa convirtiendo el minimo con ISV al neto" do
    assert_difference("Tarifa.count") do
      post servicios_url, params: { tarifa: {
        tipo_envio_id: tipo_envios(:cer).id,
        precio_libra: 4.50, moneda: "USD",
        desde_libras: 0,
        minimo_monto_con_isv: 200.00, minimo_moneda: "LPS",
        aplica_minimo: "1", activo: "1"
      } }
    end

    t = Tarifa.order(:id).last
    assert_equal BigDecimal("173.91"), t.minimo_monto,
                 "Yusef escribe 200 (con ISV) y la columna guarda el neto"
    assert_equal BigDecimal("200.00"), t.minimo_monto_con_isv
    assert_redirected_to servicios_path
  end

  test "crea una tarifa de media libra sin minimo — el caso Exchange" do
    post servicios_url, params: { tarifa: {
      tipo_envio_id: tipo_envios(:cer).id, precio_libra: 4.00, moneda: "USD",
      desde_libras: 0, aplica_minimo: "0", incremento_libras: "0.5", activo: "1"
    } }

    t = Tarifa.order(:id).last
    assert_not t.aplica_minimo
    assert_equal BigDecimal("0.5"), t.incremento_libras
  end

  test "rechaza un escalon invertido" do
    assert_no_difference("Tarifa.count") do
      post servicios_url, params: { tarifa: {
        tipo_envio_id: tipo_envios(:cer).id, precio_libra: 1, moneda: "USD",
        desde_libras: 10, hasta_libras: 5, activo: "1"
      } }
    end
    assert_response :unprocessable_entity
  end

  test "actualiza y elimina" do
    t = Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD")

    patch servicio_url(t), params: { tarifa: { precio_libra: 5.25 } }
    assert_equal BigDecimal("5.25"), t.reload.precio_libra

    assert_difference("Tarifa.count", -1) { delete servicio_url(t) }
  end

  test "solo admin entra" do
    login_as users(:cajero)

    get servicios_url

    assert_redirected_to root_path
  end
end
