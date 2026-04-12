require "test_helper"

class ProformasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:cajero)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  test "should get index" do
    get proformas_url
    assert_response :success
  end

  test "should get new without cliente_id (step 1)" do
    get new_proforma_url
    assert_response :success
    assert_select "select[name=cliente_id]"
  end

  test "should get new with cliente_id (step 2 - paquete selector)" do
    get new_proforma_url(cliente_id: clientes(:juan).id)
    assert_response :success
  end

  test "should get new in manual mode" do
    get new_proforma_url(cliente_id: clientes(:juan).id, manual: true)
    assert_response :success
  end

  test "should create proforma from paquetes" do
    paquete = paquetes(:disponible_entrega_juan)
    assert_difference "Venta.count", 1 do
      post proformas_url, params: {
        cliente_id: clientes(:juan).id,
        paquete_ids: [paquete.id]
      }
    end
    proforma = Venta.last
    assert_equal "proforma", proforma.estado
    assert_equal 1, proforma.venta_items.count
    assert_equal paquete.id, proforma.venta_items.first.paquete_id

    # Paquete should be reserved (venta_id set)
    paquete.reload
    assert_equal proforma.id, paquete.venta_id
    # Estado should NOT change yet
    assert_equal "disponible_entrega", paquete.estado

    assert_redirected_to proforma_url(proforma)
  end

  test "should create proforma with manual items" do
    assert_difference "Venta.count", 1 do
      post proformas_url, params: {
        venta: {
          cliente_id: clientes(:juan).id,
          moneda: "LPS",
          venta_items_attributes: {
            "0" => { concepto: "Flete test", peso_cobrar: 5, precio_libra: 4, subtotal: 20 }
          }
        }
      }
    end
    proforma = Venta.last
    assert_equal "proforma", proforma.estado
    assert_redirected_to proforma_url(proforma)
  end

  test "create from paquetes redirects back when no paquete_ids" do
    post proformas_url, params: {
      cliente_id: clientes(:juan).id,
      paquete_ids: []
    }
    assert_redirected_to new_proforma_url(cliente_id: clientes(:juan).id)
    assert_equal "Selecciona al menos un paquete.", flash[:alert]
  end

  test "emitir transitions proforma to pendiente and paquetes to pre_facturado" do
    paquete = paquetes(:disponible_entrega_juan2)
    proforma = Venta.build_proforma_from_paquetes(clientes(:juan), [paquete.id], user: @user)
    proforma.save!
    paquete.update_column(:venta_id, proforma.id)

    initial_saldo = clientes(:juan).saldo_pendiente.to_d

    post emitir_proforma_url(proforma)
    proforma.reload
    assert_equal "pendiente", proforma.estado
    assert proforma.saldo_pendiente.to_d > 0
    assert_equal initial_saldo + proforma.total.to_d, clientes(:juan).reload.saldo_pendiente.to_d

    paquete.reload
    assert_equal "pre_facturado", paquete.estado

    assert_redirected_to venta_url(proforma)
  end

  test "anular proforma releases paquetes" do
    paquete = paquetes(:disponible_entrega_juan2)
    proforma = Venta.build_proforma_from_paquetes(clientes(:juan), [paquete.id], user: @user)
    proforma.save!
    paquete.update_column(:venta_id, proforma.id)

    delete anular_proforma_url(proforma)
    assert_equal "anulada", proforma.reload.estado

    paquete.reload
    assert_nil paquete.venta_id
    assert_equal "disponible_entrega", paquete.estado

    assert_redirected_to proformas_url
  end

  test "facturables returns JSON for client paquetes" do
    get facturables_proformas_url(cliente_id: clientes(:juan).id), as: :json
    assert_response :success
    data = JSON.parse(response.body)
    assert_kind_of Array, data
    guias = data.map { |p| p["guia"] }
    assert_includes guias, paquetes(:disponible_entrega_juan).guia
  end

  test "facturables excludes paquetes reserved by proforma" do
    paquete = paquetes(:disponible_entrega_juan)
    proforma = Venta.create!(cliente: clientes(:juan), estado: "proforma", moneda: "LPS",
      venta_items_attributes: [{ concepto: "Flete", paquete_id: paquete.id, subtotal: 50 }])
    paquete.update_column(:venta_id, proforma.id)

    get facturables_proformas_url(cliente_id: clientes(:juan).id), as: :json
    data = JSON.parse(response.body)
    guias = data.map { |p| p["guia"] }
    assert_not_includes guias, paquete.guia
  end

  test "pdf responds with application/pdf" do
    proforma = Venta.create!(
      cliente: clientes(:juan), estado: "proforma", moneda: "LPS",
      venta_items_attributes: [{ concepto: "Flete", subtotal: 50 }]
    )
    get pdf_proforma_url(proforma)
    assert_response :success
    assert_equal "application/pdf", response.content_type
  end
end
