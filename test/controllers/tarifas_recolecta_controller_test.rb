require "test_helper"

class TarifasRecolectaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    post session_url, params: { email_address: @admin.email_address, password: "password123" }
    @tarifa = TarifaRecolecta.create!(zona: "Test setup zona", monto: 30, moneda: "USD")
  end

  test "index 200 admin" do
    get tarifas_recolecta_url
    assert_response :success
  end

  test "non-admin redirigido" do
    delete session_url
    cajero = users(:cajero)
    post session_url, params: { email_address: cajero.email_address, password: "password123" }
    get tarifas_recolecta_url
    assert_redirected_to root_path
  end

  test "create válido" do
    assert_difference "TarifaRecolecta.count", 1 do
      post tarifas_recolecta_url,
           params: { tarifa_recolecta: { zona: "Nueva zona", monto: 25, moneda: "USD", activo: true } }
    end
    assert_redirected_to tarifas_recolecta_url
  end

  test "create rechaza zona vacía" do
    assert_no_difference "TarifaRecolecta.count" do
      post tarifas_recolecta_url, params: { tarifa_recolecta: { zona: "", monto: 25, moneda: "USD" } }
    end
    assert_response :unprocessable_entity
  end

  test "edit 200" do
    get edit_tarifa_recolecta_url(@tarifa)
    assert_response :success
  end

  test "update cambia atributos" do
    patch tarifa_recolecta_url(@tarifa),
          params: { tarifa_recolecta: { zona: "Renombrada", monto: 99, moneda: "LPS" } }
    assert_redirected_to tarifas_recolecta_url
    @tarifa.reload
    assert_equal "Renombrada", @tarifa.zona
    assert_equal 99, @tarifa.monto
    assert_equal "LPS", @tarifa.moneda
  end
end
