require "test_helper"

# "RETIRA EN MIAMI" — `PR-C7.16`.
#
# Yusef mandó la etiqueta de un envío real marcada a mano: *"retira en la
# sucursal asignada al cliente, **al igual que etiquetar**"*.
#
# `Paquete#sucursal` es, textualmente en el modelo, "dónde RETIRA el cliente".
# `/etiquetar` lo respeta: manda la sucursal donde se está recibiendo a
# `sucursal_recepcion` y deja `sucursal` libre para heredarla del cliente.
# `/entrega_personal` mandaba la sucursal de Miami como `sucursal_id`, así que
# ocupaba el campo del retiro y la etiqueta imprimía "RETIRA EN MIAMI".
class EntregaPersonalSucursalRetiroTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:digitador).email_address,
                                password: "password123" }
    @miami  = sucursales(:miami)
    @retiro = sucursales(:humuya_tgu)
    clientes(:juan).update!(sucursal_retiro: @retiro)
  end

  def attrs(**extra)
    { cliente_id: clientes(:juan).id,
      tipo_envio_id: tipo_envios(:cer).id,
      sucursal_recepcion_id: @miami.id,
      proveedor_id: proveedores(:driver_entrega).id,
      descripcion: "Paquete de prueba",
      peso: 5 }.merge(extra)
  end

  test "el paquete queda con la sucursal de retiro del cliente, no con Miami" do
    post entrega_personal_index_url, params: { paquete: attrs }

    p = Paquete.order(:id).last
    assert_equal @retiro, p.sucursal,        "la sucursal de retiro se llenó con Miami"
    assert_equal @miami,  p.sucursal_recepcion
  end

  test "el tracking EP se sigue generando con el codigo de Miami" do
    post entrega_personal_index_url, params: { paquete: attrs }

    assert_match(/\AEP-\d{4}-SMI-/, Paquete.order(:id).last.tracking,
                 "al mudar Miami a sucursal_recepcion se rompió la generación del tracking")
  end

  # `crear_split!` crea las cajas de una: si la herencia no viaja en `attrs`,
  # la primera caja se valida con el campo vacío.
  test "en un split de tres cajas las tres heredan la sucursal de retiro" do
    post entrega_personal_index_url, params: {
      paquete: attrs(cajas: { "1" => { peso: 5 }, "2" => { peso: 8 }, "3" => { peso: 2 } })
    }

    cajas = Paquete.order(:id).last(3)
    assert_equal [ @retiro ] * 3, cajas.map(&:sucursal)
    assert_equal 1, cajas.map(&:tracking).uniq.size
  end

  test "la etiqueta imprime la sucursal del cliente" do
    post entrega_personal_index_url, params: { paquete: attrs }
    p = Paquete.order(:id).last

    get etiqueta_paquete_url(p)

    assert_response :success
    assert_match(/RETIRA EN/, response.body)
    assert_match(/#{@retiro.nombre.upcase}/i, response.body)
    assert_no_match(/RETIRA EN<\/div>\s*<div[^>]*>\s*MIAMI/i, response.body)
  end

  # Yusef: *"agregue detalle de 3 cajas, aquí debería crear las etiquetas para 3
  # cajas"*. La etiqueta se le pega a **cada caja**.
  test "un split de tres cajas imprime tres etiquetas de una vez" do
    post entrega_personal_index_url, params: {
      paquete: attrs(cajas: { "1" => { peso: 5 }, "2" => { peso: 8 }, "3" => { peso: 2 } })
    }
    caja1 = Paquete.order(:id).last(3).first

    get etiqueta_paquete_url(caja1, hermanas: 1)

    assert_response :success
    assert_select "[data-campo=sucursal]", count: 3
  end

  # *"El Warehouse Receipt es al revés: solo imprimís uno, donde detalla todo lo
  # que recibiste."* Una fila por caja, y el total de libras a cobrar.
  test "el Warehouse Receipt detalla las tres cajas en un solo documento" do
    post entrega_personal_index_url, params: {
      paquete: attrs(cajas: {
        "1" => { peso: 5, alto: 10, largo: 5,  ancho: 15 },
        "2" => { peso: 8, alto: 12, largo: 6,  ancho: 20 },
        "3" => { peso: 2, alto: 30, largo: 30, ancho: 30 }
      })
    }
    cajas = Paquete.order(:id).last(3)

    get warehouse_receipt_paquete_url(cajas.first)

    assert_response :success
    assert_select "table.wr-pkg tbody tr", count: 3,
                  message: "el WR seguía saliendo por una sola caja"
    assert_select "table.wr-totals td.value", text: "3", count: 1

    # El número que él pidió: la suma del mayor de cada caja. Con estas medidas
    # da 177.0, mientras que el volumétrico total da 176.5 — por eso hacía falta
    # la fila, y por eso este test compara contra los dos.
    esperado = cajas.sum { |c| c.peso_cobrar.to_f }.round(2)
    assert_select "table.wr-totals td.value", text: /#{esperado} LB/
    assert_select "table.wr-totals td.label", text: /Libras a cobrar/i
    assert_not_equal esperado, cajas.sum { |c| c.peso_volumetrico.to_f }.round(2),
                     "con estas medidas el test no distingue las dos reglas"
  end

  # El popup del WR puede bloquearlo el navegador —Chrome permite uno solo por
  # gesto y ese se lo lleva la impresión de etiquetas—, así que el link también
  # va en el aviso.
  test "el aviso trae el link al Warehouse Receipt" do
    post entrega_personal_index_url, params: { paquete: attrs }, as: :turbo_stream
    p = Paquete.order(:id).last

    assert_match(warehouse_receipt_paquete_path(p), response.body)
  end

  # La trampa de la pantalla gemela: el Agent del WR mostraba `paquete.sucursal`
  # y decía "Miami" **gracias al bug**. Al arreglar la etiqueta habría empezado a
  # decir la sucursal de retiro si no se movía con ella.
  test "el Agent del Warehouse Receipt sigue diciendo donde se recibio" do
    post entrega_personal_index_url, params: { paquete: attrs }
    p = Paquete.order(:id).last

    get warehouse_receipt_paquete_url(p)

    assert_response :success
    assert_match(/#{@miami.nombre}/, response.body)
  end

  # Los EP viejos se crearon con Miami en `sucursal`; el fallback de
  # `sucursal_del_numero` los deja andando.
  test "sigue andando si el form manda Miami en el campo viejo" do
    post entrega_personal_index_url, params: {
      paquete: attrs(sucursal_recepcion_id: nil, sucursal_id: @miami.id)
    }

    assert_match(/\AEP-\d{4}-SMI-/, Paquete.order(:id).last.tracking)
  end
end
