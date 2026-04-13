require "test_helper"

class PreFacturasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:cajero)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @pre_factura = pre_facturas(:borrador_juan)
    @cliente = clientes(:juan)
  end

  test "should get index" do
    get pre_facturas_url
    assert_response :success
  end

  test "index filters by estado" do
    get pre_facturas_url, params: { estado: "pendiente" }
    assert_response :success
  end

  test "index filters by cliente_id" do
    get pre_facturas_url, params: { cliente_id: @cliente.id }
    assert_response :success
  end

  test "index filters by search" do
    get pre_facturas_url, params: { q: "PF-000001" }
    assert_response :success
  end

  test "should get new without cliente" do
    get new_pre_factura_url
    assert_response :success
  end

  test "should get new with cliente_id" do
    get new_pre_factura_url, params: { cliente_id: @cliente.id }
    assert_response :success
  end

  test "create builds pre_factura from paquetes" do
    paquete = paquetes(:disponible_entrega_juan)
    assert_difference "PreFactura.count", 1 do
      post pre_facturas_url, params: {
        cliente_id: @cliente.id,
        paquete_ids: [paquete.id]
      }
    end
    assert_redirected_to edit_pre_factura_url(PreFactura.last)
  end

  test "create fails without paquete_ids" do
    assert_no_difference "PreFactura.count" do
      post pre_facturas_url, params: { cliente_id: @cliente.id, paquete_ids: [] }
    end
    assert_redirected_to new_pre_factura_url(cliente_id: @cliente.id)
  end

  test "should show pre_factura" do
    get pre_factura_url(@pre_factura)
    assert_response :success
  end

  test "should get edit" do
    get edit_pre_factura_url(@pre_factura)
    assert_response :success
  end

  test "should update pre_factura notas" do
    patch pre_factura_url(@pre_factura), params: { pre_factura: { notas: "Nota test" } }
    assert_redirected_to edit_pre_factura_url(@pre_factura)
    @pre_factura.reload
    assert_equal "Nota test", @pre_factura.notas
  end

  test "confirmar transitions to pendiente" do
    post confirmar_pre_factura_url(@pre_factura)
    @pre_factura.reload
    assert @pre_factura.pendiente?
  end

  test "facturar creates Venta and redirects to venta" do
    # Seed a paquete-linked pre_factura for realistic facturar
    paquete = paquetes(:disponible_entrega_juan)
    pf = PreFactura.build_from_paquetes(@cliente, [paquete.id], user: @user)
    pf.save!

    assert_difference "Venta.count", 1 do
      post facturar_pre_factura_url(pf)
    end
    pf.reload
    assert pf.facturado?
    assert_redirected_to venta_url(Venta.last)
  end

  test "anular transitions to anulado" do
    delete anular_pre_factura_url(@pre_factura)
    @pre_factura.reload
    assert @pre_factura.anulado?
    assert_redirected_to pre_facturas_url
  end

  test "facturables returns json for cliente" do
    get facturables_pre_facturas_url, params: { cliente_id: @cliente.id }, as: :json
    assert_response :success
    body = JSON.parse(response.body)
    assert_kind_of Array, body
  end

  test "digitador cannot access pre_facturas" do
    delete session_url
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }
    get pre_facturas_url
    assert_redirected_to root_url
  end
end
