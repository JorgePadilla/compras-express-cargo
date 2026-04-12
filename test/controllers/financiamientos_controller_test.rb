require "test_helper"

class FinanciamientosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:cajero)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @financiamiento = financiamientos(:activo_juan)
  end

  test "should get index" do
    get financiamientos_url
    assert_response :success
  end

  test "should show financiamiento" do
    get financiamiento_url(@financiamiento)
    assert_response :success
  end

  test "should get new with venta_id" do
    get new_financiamiento_url(venta_id: ventas(:pendiente_juan).id)
    assert_response :success
  end

  test "should create financiamiento and generate cuotas" do
    assert_difference "Financiamiento.count", 1 do
      post financiamientos_url, params: {
        financiamiento: {
          venta_id: ventas(:pendiente_juan).id,
          cliente_id: clientes(:juan).id,
          moneda: "LPS",
          monto_total: 60,
          numero_cuotas: 3,
          frecuencia: "mensual",
          fecha_inicio: Date.current
        }
      }
    end
    fn = Financiamiento.last
    assert_equal 3, fn.financiamiento_cuotas.count
    assert_redirected_to financiamiento_url(fn)
  end

  test "pagar_cuota creates pago and marks cuota as pagada" do
    cuota = financiamiento_cuotas(:cuota_1)
    assert_difference ["Pago.count", "Recibo.count"], 1 do
      post pagar_cuota_financiamiento_url(@financiamiento, cuota_id: cuota.id, metodo_pago: "efectivo")
    end
    assert cuota.reload.pagada?
    assert_redirected_to financiamiento_url(@financiamiento)
  end

  test "cancelar financiamiento" do
    delete cancelar_financiamiento_url(@financiamiento)
    assert @financiamiento.reload.cancelado?
    assert_redirected_to financiamiento_url(@financiamiento)
  end

  test "digitador cannot access financiamientos" do
    delete session_url
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }
    get financiamientos_url
    assert_redirected_to root_url
  end
end
