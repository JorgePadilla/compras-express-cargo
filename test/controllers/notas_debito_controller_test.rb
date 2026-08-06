require "test_helper"

class NotasDebitoControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:cajero)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @nd = notas_debito(:nd_creada)
    @venta = ventas(:pendiente_juan)
  end

  test "should get index" do
    get notas_debito_url
    assert_response :success
  end

  test "index filters by estado" do
    get notas_debito_url, params: { estado: "creado" }
    assert_response :success
  end

  test "should show nota debito" do
    get nota_debito_url(@nd)
    assert_response :success
  end

  test "should get new with venta_id" do
    get new_nota_debito_url(venta_id: @venta.id)
    assert_response :success
  end

  test "should create nota debito" do
    assert_difference "NotaDebito.count", 1 do
      post notas_debito_url, params: {
        venta_id: @venta.id,
        nota_debito: {
          motivo: "ajuste_manual",
          notas: "Test creation",
          nota_debito_items_attributes: {
            "0" => { concepto: "Test item", subtotal: 50.00 }
          }
        }
      }
    end
    assert_redirected_to nota_debito_url(NotaDebito.last)
  end

  test "should get edit for creado" do
    get edit_nota_debito_url(@nd)
    assert_response :success
  end

  test "should update when creado" do
    patch nota_debito_url(@nd), params: { nota_debito: { notas: "Updated" } }
    assert_redirected_to nota_debito_url(@nd)
    assert_equal "Updated", @nd.reload.notas
  end

  # PR-13.e: emitir pasa a pedir el PIN de un supervisor — es cuando el cliente
  # pasa a deber más. El detalle está en `emision_nota_autorizada_test.rb`.
  test "emitir transitions to emitido con autorizacion" do
    supervisor = User.create!(
      nombre: "Supervisora ND", email_address: "supnd@cec.test", password: "password123",
      rol: "supervisor_caja", ubicacion: "honduras", pin: "1234"
    )

    post emitir_nota_debito_url(@nd), params: { autorizacion: {
      autorizado_por_id: supervisor.id, pin: "1234", motivo: "Ajuste aprobado"
    } }

    assert_equal "emitido", @nd.reload.estado
    assert_redirected_to nota_debito_url(@nd)
  end

  test "emitir sin autorizacion no hace nada" do
    post emitir_nota_debito_url(@nd)

    assert_equal "creado", @nd.reload.estado
  end

  test "anular transitions from emitido" do
    nd = notas_debito(:nd_emitida)
    delete anular_nota_debito_url(nd)
    assert_equal "anulado", nd.reload.estado
    assert_redirected_to nota_debito_url(nd)
  end

  test "pdf responds with application/pdf" do
    get pdf_nota_debito_url(@nd)
    assert_response :success
    assert_equal "application/pdf", response.content_type
  end

  test "enviar_email enqueues mailer" do
    nd = notas_debito(:nd_emitida)
    assert_enqueued_emails 1 do
      post enviar_email_nota_debito_url(nd)
    end
    assert_redirected_to nota_debito_url(nd)
  end

  test "digitador cannot access notas debito" do
    delete session_url
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }
    get notas_debito_url
    assert_redirected_to root_url
  end
end
