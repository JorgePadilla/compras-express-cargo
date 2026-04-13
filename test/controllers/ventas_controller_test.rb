require "test_helper"

class VentasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:cajero)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @venta = ventas(:pendiente_juan)
  end

  test "should get index" do
    get ventas_url
    assert_response :success
  end

  test "index filters by estado" do
    get ventas_url, params: { estado: "pagada" }
    assert_response :success
  end

  test "should show venta" do
    get venta_url(@venta)
    assert_response :success
  end

  test "should get edit" do
    get edit_venta_url(@venta)
    assert_response :success
  end

  test "should update notas" do
    patch venta_url(@venta), params: { venta: { notas: "Test nota" } }
    assert_redirected_to edit_venta_url(@venta)
    assert_equal "Test nota", @venta.reload.notas
  end

  test "registrar_pago full amount transitions to pagada and creates recibo" do
    assert_difference ["Pago.count", "Recibo.count"], 1 do
      post registrar_pago_venta_url(@venta), params: {
        monto: @venta.total, metodo_pago: "efectivo"
      }
    end
    @venta.reload
    assert @venta.pagada?
    assert_redirected_to recibo_url(Recibo.last)
  end

  test "registrar_pago partial keeps pendiente" do
    half = (@venta.total.to_d / 2).round(2)
    post registrar_pago_venta_url(@venta), params: { monto: half, metodo_pago: "efectivo" }
    @venta.reload
    assert @venta.pendiente?
  end

  test "registrar_pago fails without monto" do
    post registrar_pago_venta_url(@venta), params: { metodo_pago: "efectivo" }
    assert_redirected_to venta_url(@venta)
  end

  test "anular unpaid venta" do
    delete anular_venta_url(@venta)
    assert @venta.reload.anulada?
    assert_redirected_to ventas_url
  end

  test "anular pagada venta fails" do
    delete anular_venta_url(ventas(:pagada_maria))
    assert_not ventas(:pagada_maria).reload.anulada?
  end

  test "pdf responds with application/pdf" do
    get pdf_venta_url(@venta)
    assert_response :success
    assert_equal "application/pdf", response.content_type
  end

  test "enviar_email enqueues mailer" do
    assert_enqueued_emails 1 do
      post enviar_email_venta_url(@venta)
    end
    assert_redirected_to venta_url(@venta)
  end

  test "digitador cannot access ventas" do
    delete session_url
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }
    get ventas_url
    assert_redirected_to root_url
  end
end
