require "test_helper"

# PR-M8 / C21-10. Yusef se corrigió solo en la reunión del 2026-08-29:
#
#   > "Ahí no va la guía; en la prefactura va el manifiesto, la caja del
#   >  manifiesto."
#
# PR-P.11b · La pantalla a mano que elegía el manifiesto se fue: la
# pre-factura nace en la hoja de preparación, que ya trabaja por manifiesto
# (`hoja_de_preparacion_test`), y F9 se lo pone (`guardar_pre_factura_auditada_test`).
# Acá quedan el filtro del índice y el vínculo `paquetes.pre_factura_id`, que
# vale venga de donde venga la pre-factura. Se arman con `build_from_paquetes`
# hasta P.11c.
class PreFacturaManifiestoTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:cajero)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @cliente = clientes(:juan)
    @manifiesto = manifiestos(:enviado)
    @dentro = paquetes(:disponible_entrega_juan)
    @dentro.update_columns(manifiesto_id: @manifiesto.id, estado: "en_aduana")
  end

  def pre_facturar(paquete)
    PreFactura.build_from_paquetes(@cliente, [ paquete.id ], user: @user).tap(&:save!)
  end

  test "el index filtra por manifiesto" do
    pf = pre_facturas(:borrador_juan)
    pf.update_column(:manifiesto_id, @manifiesto.id)
    get pre_facturas_url, params: { manifiesto_id: @manifiesto.id }
    assert_response :success
    assert_select "td", text: /#{@manifiesto.numero}/
  end

  # El candado de `build_from_paquetes`: un id que no es facturable no entra.
  test "un paquete que no es facturable no entra aunque manden su id" do
    @dentro.update_column(:estado, "recibido_miami")
    pf = PreFactura.build_from_paquetes(@cliente, [ @dentro.id ], user: @user)
    assert_empty pf.pre_factura_items
  end

  # El vínculo que faltaba: `paquetes.pre_factura_id` lo leían tres lugares y
  # solo lo escribían los seeds.
  test "guardar la pre-factura estampa pre_factura_id en el paquete, y anular lo suelta" do
    pf = pre_facturar(@dentro)
    assert_equal pf.id, @dentro.reload.pre_factura_id
    assert_not_includes Paquete.facturables, @dentro

    assert pf.anular!
    assert_nil @dentro.reload.pre_factura_id
    assert_includes Paquete.facturables, @dentro
  end

  # El contrapeso del estampado: si se quita la línea, el paquete se suelta.
  # Sin esto quedaba estampado para siempre — fuera de `facturables`, con
  # `cobrada_o_entregada?` en true, y sin poder facturarse ni borrarse.
  test "quitar la línea del paquete lo devuelve a facturables" do
    pf = pre_facturar(@dentro)
    pf.pre_factura_items.find_by(paquete_id: @dentro.id).destroy!

    assert_nil @dentro.reload.pre_factura_id
    assert_includes Paquete.facturables, @dentro
  end

  # Un paquete puede llevar varias líneas en el mismo documento —el flete y sus
  # cargos automáticos—. Que muera una auto no lo saca del cobro.
  test "borrar una línea auto no suelta el paquete si le queda el flete" do
    @dentro.update_columns(recolecta_solicitada: true, recolecta_monto: 35.0, recolecta_moneda: "USD")
    pf = pre_facturar(@dentro)
    auto = pf.pre_factura_items.auto.find_by(paquete_id: @dentro.id)
    assert auto, "la línea auto de recolecta debería existir"

    auto.destroy!

    assert_equal pf.id, @dentro.reload.pre_factura_id
  end
end
