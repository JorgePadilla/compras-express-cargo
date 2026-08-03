require "test_helper"

# PR-10.b: endpoint JSON del "valor a pagar".
class CotizadorControllerTest < ActionDispatch::IntegrationTest
  setup do
    login_as users(:digitador)
    Tarifa.delete_all
  end

  def login_as(user)
    delete session_url
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  test "devuelve el cobro en las dos monedas" do
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD")

    get cotizador_url, params: { tipo_envio_id: tipo_envios(:cer).id,
                                 cliente_id: clientes(:juan).id, peso: 10 }

    assert_response :success
    d = JSON.parse(response.body)
    assert d["ok"]
    assert d["total"]["lps"] > d["total"]["usd"], "el monto en Lempiras debe ser el mayor"
    assert_in_delta 45.0, d["subtotal"]["usd"], 0.05
  end

  test "sin tipo de envio no cotiza" do
    get cotizador_url, params: { cliente_id: clientes(:juan).id, peso: 10 }

    assert_response :success
    d = JSON.parse(response.body)
    assert_not d["ok"]
    assert_equal "sin_tipo_envio", d["motivo"]
  end

  test "reporta cuando aplico el minimo" do
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD",
                   minimo_monto: 173.91, minimo_moneda: "LPS")

    get cotizador_url, params: { tipo_envio_id: tipo_envios(:cer).id,
                                 cliente_id: clientes(:juan).id, peso: 1 }

    d = JSON.parse(response.body)
    assert d["aplico_minimo"]
    assert_in_delta 173.91, d["subtotal"]["lps"], 0.01
  end

  test "reporta cuando no hay tarifa cargada" do
    get cotizador_url, params: { tipo_envio_id: tipo_envios(:cer).id, peso: 5 }

    d = JSON.parse(response.body)
    assert d["ok"]
    assert_not d["tarifa_encontrada"]
  end

  test "usa el peso volumetrico cuando supera al real" do
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 1.00, moneda: "USD")

    get cotizador_url, params: { tipo_envio_id: tipo_envios(:cer).id, peso: 2,
                                 alto: 20, largo: 20, ancho: 20 }

    d = JSON.parse(response.body)
    assert_equal 48.5, d["peso_cobrar"]
  end

  test "un repartidor no puede cotizar" do
    login_as users(:repartidor)

    get cotizador_url, params: { tipo_envio_id: tipo_envios(:cer).id, peso: 5 }

    assert_redirected_to root_path
  end
end
