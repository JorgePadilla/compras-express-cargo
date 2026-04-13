require "test_helper"

class EgresosCajaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:cajero)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  test "should get index" do
    get egresos_caja_url
    assert_response :success
  end

  test "should get new" do
    get new_egreso_caja_url
    assert_response :success
  end

  test "should create egreso" do
    assert_difference "EgresoCaja.count", 1 do
      post egresos_caja_url, params: {
        egreso_caja: { monto: 50, concepto: "Gasolina", metodo_pago: "efectivo", categoria: "transporte" }
      }
    end
    assert_redirected_to egreso_caja_url(EgresoCaja.last)
  end

  test "should show egreso" do
    egreso = EgresoCaja.create!(
      apertura_caja: aperturas_caja(:hoy),
      monto: 30,
      concepto: "Test",
      metodo_pago: "efectivo",
      registrado_por: @user
    )
    get egreso_caja_url(egreso)
    assert_response :success
  end

  test "new redirects if no caja abierta" do
    AperturaCaja.where(fecha: Date.current).delete_all
    get new_egreso_caja_url
    assert_redirected_to caja_url
  end
end
