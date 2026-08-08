require "test_helper"

class NotasCreditoControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @nc = notas_credito(:nc_creada)
    @venta = ventas(:pendiente_juan)
  end

  test "should get index" do
    get notas_credito_url
    assert_response :success
  end

  test "index filters by estado" do
    get notas_credito_url, params: { estado: "creado" }
    assert_response :success
  end

  test "should show nota credito" do
    get nota_credito_url(@nc)
    assert_response :success
  end

  test "should get new with venta_id" do
    get new_nota_credito_url(venta_id: @venta.id)
    assert_response :success
  end

  test "should create nota credito" do
    assert_difference "NotaCredito.count", 1 do
      post notas_credito_url, params: {
        venta_id: @venta.id,
        nota_credito: {
          motivo: "descuento",
          notas: "Test creation",
          nota_credito_items_attributes: {
            "0" => { concepto: "Test item", subtotal: 30.00 }
          }
        }
      }
    end
    assert_redirected_to nota_credito_url(NotaCredito.last)
  end

  test "should get edit for creado" do
    get edit_nota_credito_url(@nc)
    assert_response :success
  end

  test "should update when creado" do
    patch nota_credito_url(@nc), params: { nota_credito: { notas: "Updated" } }
    assert_redirected_to nota_credito_url(@nc)
    assert_equal "Updated", @nc.reload.notas
  end

  # PR-13.e: emitir pasa a pedir el PIN de un supervisor — es cuando el saldo
  # del cliente baja. El detalle está en `emision_nota_autorizada_test.rb`.
  test "emitir transitions to emitido con autorizacion" do
    supervisor = User.create!(
      nombre: "Supervisora NC", email_address: "supnc@cec.test", password: "password123",
      rol: "supervisor_caja", ubicacion: "honduras", pin: "1234"
    )

    post emitir_nota_credito_url(@nc), params: { autorizacion: {
      autorizado_por_id: supervisor.id, pin: "1234", motivo: "Devolucion aprobada"
    } }

    assert_equal "emitido", @nc.reload.estado
    assert_redirected_to nota_credito_url(@nc)
  end

  test "emitir sin autorizacion no hace nada" do
    post emitir_nota_credito_url(@nc)

    assert_equal "creado", @nc.reload.estado
  end

  test "anular transitions from emitido" do
    nc = notas_credito(:nc_emitida)
    delete anular_nota_credito_url(nc)
    assert_equal "anulado", nc.reload.estado
    assert_redirected_to nota_credito_url(nc)
  end

  test "pdf responds with application/pdf" do
    get pdf_nota_credito_url(@nc)
    assert_response :success
    assert_equal "application/pdf", response.content_type
  end

  test "enviar_email enqueues mailer" do
    nc = notas_credito(:nc_emitida)
    assert_enqueued_emails 1 do
      post enviar_email_nota_credito_url(nc)
    end
    assert_redirected_to nota_credito_url(nc)
  end

  test "cajero cannot access notas credito" do
    delete session_url
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }
    get notas_credito_url
    assert_redirected_to root_url
  end
end
