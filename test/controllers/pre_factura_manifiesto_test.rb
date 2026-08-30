require "test_helper"

# PR-M8 / C21-10. Yusef se corrigió solo en la reunión del 2026-08-29:
#
#   > "Ahí no va la guía; en la prefactura va el manifiesto, la caja del
#   >  manifiesto."
#   > "Está malo… porque no es la guía del proveedor, es el manifiesto."
#
# Hasta hoy el número se tipeaba a mano. Estos tests cubren las tres puertas
# —la pantalla, el JSON del preview y el create— porque el bug recurrente de
# este repo es arreglar una y olvidar la gemela.
class PreFacturaManifiestoTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:cajero)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @cliente = clientes(:juan)
    @manifiesto = manifiestos(:enviado)
    @dentro = paquetes(:disponible_entrega_juan)
    @fuera  = paquetes(:disponible_entrega_juan2)
    @dentro.update_columns(manifiesto_id: @manifiesto.id, estado: "en_aduana")
    @fuera.update_columns(manifiesto_id: nil, estado: "disponible_entrega")
  end

  test "el selector solo ofrece manifiestos con carga por facturar" do
    assert_includes Manifiesto.con_carga_por_facturar, @manifiesto
    assert_not_includes Manifiesto.con_carga_por_facturar, manifiestos(:creado)
  end

  test "un manifiesto sin carga pendiente se cae solo de la lista" do
    @dentro.update_column(:pre_factura_id, pre_facturas(:borrador_juan).id)
    assert_not_includes Manifiesto.con_carga_por_facturar, @manifiesto
  end

  test "sin manifiesto la pantalla lista todos los facturables del cliente" do
    get new_pre_factura_url, params: { cliente_id: @cliente.id }
    assert_response :success
    assert_select "input#paquete_#{@dentro.id}"
    assert_select "input#paquete_#{@fuera.id}"
  end

  test "con manifiesto la pantalla filtra a la carga de ese manifiesto" do
    get new_pre_factura_url, params: { cliente_id: @cliente.id, manifiesto_id: @manifiesto.id }
    assert_response :success
    assert_select "input#paquete_#{@dentro.id}"
    assert_select "input#paquete_#{@fuera.id}", false
    assert_select "input[name=manifiesto_id][value=?]", @manifiesto.id.to_s
  end

  test "el JSON del preview filtra igual que la pantalla" do
    get facturables_pre_facturas_url,
        params: { cliente_id: @cliente.id, manifiesto_id: @manifiesto.id }, as: :json
    ids = response.parsed_body.map { |p| p["id"] }
    assert_includes ids, @dentro.id
    assert_not_includes ids, @fuera.id
  end

  test "crear la pre-factura guarda el manifiesto que se estaba trabajando" do
    assert_difference "PreFactura.count", 1 do
      post pre_facturas_url, params: {
        cliente_id: @cliente.id, manifiesto_id: @manifiesto.id, paquete_ids: [ @dentro.id ]
      }
    end
    assert_equal @manifiesto.id, PreFactura.order(:id).last.manifiesto_id
  end

  test "sin manifiesto seleccionado la pre-factura queda sin amarrar" do
    post pre_facturas_url, params: { cliente_id: @cliente.id, paquete_ids: [ @fuera.id ] }
    assert_nil PreFactura.order(:id).last.manifiesto_id
  end

  test "un paquete en aduana se puede pre-facturar" do
    assert_difference "PreFactura.count", 1 do
      post pre_facturas_url, params: { cliente_id: @cliente.id, paquete_ids: [ @dentro.id ] }
    end
    assert_includes PreFactura.order(:id).last.paquetes, @dentro
  end

  # El candado nuevo de `build_from_paquetes`: la lista de la pantalla ya
  # filtraba, pero el create tomaba cualquier id que le mandaran.
  test "un paquete que no es facturable no entra aunque manden su id" do
    @dentro.update_column(:estado, "recibido_miami")
    post pre_facturas_url, params: { cliente_id: @cliente.id, paquete_ids: [ @dentro.id ] }
    assert_not_includes PreFactura.order(:id).last&.paquetes.to_a, @dentro
  end

  # El vínculo que faltaba: `paquetes.pre_factura_id` lo leían tres lugares y
  # solo lo escribían los seeds.
  test "crear la pre-factura estampa pre_factura_id en el paquete" do
    post pre_facturas_url, params: {
      cliente_id: @cliente.id, manifiesto_id: @manifiesto.id, paquete_ids: [ @dentro.id ]
    }
    pf = PreFactura.order(:id).last
    assert_equal pf.id, @dentro.reload.pre_factura_id
    assert_not_includes Paquete.facturables, @dentro
  end

  test "el manifiesto se cae solo de la lista cuando ya no le queda carga" do
    post pre_facturas_url, params: {
      cliente_id: @cliente.id, manifiesto_id: @manifiesto.id, paquete_ids: [ @dentro.id ]
    }
    assert_not_includes Manifiesto.con_carga_por_facturar, @manifiesto.reload
  end

  test "anular devuelve el paquete a la lista" do
    post pre_facturas_url, params: {
      cliente_id: @cliente.id, manifiesto_id: @manifiesto.id, paquete_ids: [ @dentro.id ]
    }
    pf = PreFactura.order(:id).last
    assert pf.anular!
    assert_nil @dentro.reload.pre_factura_id
    assert_includes Paquete.facturables, @dentro
  end

  test "el index filtra por manifiesto" do
    pf = pre_facturas(:borrador_juan)
    pf.update_column(:manifiesto_id, @manifiesto.id)
    get pre_facturas_url, params: { manifiesto_id: @manifiesto.id }
    assert_response :success
    assert_select "td", text: /#{@manifiesto.numero}/
  end
end
