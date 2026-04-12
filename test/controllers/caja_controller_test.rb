require "test_helper"

class CajaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:cajero)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  test "should get show (Mi Dia)" do
    get caja_url
    assert_response :success
  end

  test "apertura creates new apertura for today" do
    AperturaCaja.where(fecha: Date.current).delete_all
    assert_difference "AperturaCaja.count", 1 do
      post apertura_caja_url, params: { monto_apertura: 1000 }
    end
    assert_redirected_to caja_url
  end

  test "apertura fails if already exists for today" do
    post apertura_caja_url, params: { monto_apertura: 500 }
    assert_redirected_to caja_url
    assert_match /Ya existe/, flash[:alert]
  end

  test "cierre closes today's apertura" do
    post cierre_caja_url, params: { monto_cierre: 500 }
    assert_redirected_to caja_url
    assert aperturas_caja(:hoy).reload.cerrada?
  end

  test "cierre fails when no apertura open" do
    AperturaCaja.where(fecha: Date.current).delete_all
    post cierre_caja_url, params: { monto_cierre: 100 }
    assert_redirected_to caja_url
    assert_match /No hay caja/, flash[:alert]
  end

  test "should get historial" do
    get historial_caja_url
    assert_response :success
  end

  test "unauthorized user redirected" do
    delete session_url
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }
    get caja_url
    assert_redirected_to root_url
  end
end
