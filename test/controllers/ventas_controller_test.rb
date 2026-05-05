require "test_helper"

class VentasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:cajero)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @venta = facturas(:pendiente_juan)
  end

  test "should get index" do
    get facturas_url
    assert_response :success
  end

  test "index filters by estado" do
    get facturas_url, params: { estado: "pagada" }
    assert_response :success
  end

  test "should show venta" do
    get factura_url(@venta)
    assert_response :success
  end

  test "should get edit" do
    get edit_factura_url(@venta)
    assert_response :success
  end

  test "should update notas" do
    patch factura_url(@venta), params: { factura: { notas: "Test nota" } }
    assert_redirected_to edit_factura_url(@venta)
    assert_equal "Test nota", @venta.reload.notas
  end

  test "registrar_pago full amount transitions to pagada and creates recibo" do
    assert_difference ["Pago.count", "Recibo.count"], 1 do
      post registrar_pago_factura_url(@venta), params: {
        monto: @venta.total, metodo_pago: "efectivo"
      }
    end
    @venta.reload
    assert @venta.pagada?
    assert_redirected_to recibo_url(Recibo.last)
  end

  test "registrar_pago partial keeps pendiente" do
    half = (@venta.total.to_d / 2).round(2)
    post registrar_pago_factura_url(@venta), params: { monto: half, metodo_pago: "efectivo" }
    @venta.reload
    assert @venta.pendiente?
  end

  test "registrar_pago fails without monto" do
    post registrar_pago_factura_url(@venta), params: { metodo_pago: "efectivo" }
    assert_redirected_to factura_url(@venta)
  end

  test "anular unpaid venta" do
    delete anular_factura_url(@venta)
    assert @venta.reload.anulada?
    assert_redirected_to facturas_url
  end

  test "anular pagada venta fails" do
    delete anular_factura_url(facturas(:pagada_maria))
    assert_not facturas(:pagada_maria).reload.anulada?
  end

  test "pdf responds with application/pdf" do
    get pdf_factura_url(@venta)
    assert_response :success
    assert_equal "application/pdf", response.content_type
  end

  test "enviar_email enqueues mailer" do
    assert_enqueued_emails 1 do
      post enviar_email_factura_url(@venta)
    end
    assert_redirected_to factura_url(@venta)
  end

  test "digitador cannot access ventas" do
    delete session_url
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }
    get facturas_url
    assert_redirected_to root_url
  end

  # ── PR-FAC.3c.2: lifecycle actions (new/create/confirmar/emitir) ──

  test "new sin cliente_id muestra selector" do
    get new_factura_url
    assert_response :success
  end

  test "new con cliente_id carga paquetes facturables" do
    get new_factura_url, params: { cliente_id: clientes(:juan).id }
    assert_response :success
  end

  test "create crea factura en estado borrador desde paquetes" do
    paquete = paquetes(:disponible_entrega_juan)
    assert_difference "Factura.count", 1 do
      post facturas_url, params: { cliente_id: clientes(:juan).id, paquete_ids: [paquete.id] }
    end
    factura = Factura.last
    assert_equal "borrador", factura.estado
    assert_redirected_to edit_factura_url(factura)
  end

  test "create sin paquete_ids redirige con alert" do
    post facturas_url, params: { cliente_id: clientes(:juan).id, paquete_ids: [] }
    assert_redirected_to new_factura_url(cliente_id: clientes(:juan).id)
    assert_equal "Selecciona al menos un paquete.", flash[:alert]
  end

  test "confirmar transiciona borrador → confirmado" do
    factura = Factura.build_from_paquetes(clientes(:juan), [paquetes(:disponible_entrega_juan).id], user: @user)
    factura.save!

    post confirmar_factura_url(factura)
    assert_equal "confirmado", factura.reload.estado
    assert_redirected_to edit_factura_url(factura)
  end

  test "emitir transiciona confirmado → emitido y redirige a show" do
    factura = Factura.build_from_paquetes(clientes(:juan), [paquetes(:disponible_entrega_juan).id], user: @user)
    factura.save!
    factura.confirmar!

    post emitir_factura_url(factura)
    assert_equal "emitido", factura.reload.estado
    assert_redirected_to factura_url(factura)
  end

  test "facturables devuelve JSON con paquetes facturables" do
    get facturables_facturas_url, params: { cliente_id: clientes(:juan).id }
    assert_response :success
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
  end
end
