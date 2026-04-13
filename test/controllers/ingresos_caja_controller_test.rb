require "test_helper"

class IngresosCajaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:cajero)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  test "should get index" do
    get ingresos_caja_url
    assert_response :success
  end

  test "should get new" do
    get new_ingreso_caja_url
    assert_response :success
  end

  test "should create ingreso" do
    assert_difference "IngresoCaja.count", 1 do
      post ingresos_caja_url, params: {
        ingreso_caja: { monto: 100, concepto: "Embalaje", metodo_pago: "efectivo" }
      }
    end
    assert_redirected_to ingreso_caja_url(IngresoCaja.last)
  end

  test "should show ingreso" do
    ingreso = IngresoCaja.create!(
      apertura_caja: aperturas_caja(:hoy),
      monto: 50,
      concepto: "Test",
      metodo_pago: "efectivo",
      registrado_por: @user
    )
    get ingreso_caja_url(ingreso)
    assert_response :success
  end

  test "new redirects if no caja abierta" do
    AperturaCaja.where(fecha: Date.current).delete_all
    get new_ingreso_caja_url
    assert_redirected_to caja_url
  end
end
