require "test_helper"

# PR-C6.22: etiquetar es **recibir**, no empacar.
#
# Yusef, 2026-08-08, revisando la bitácora de un paquete recién etiquetado:
#
#   "Empacado dice, y **empacado no es lo que sigue**... queda aquí en
#    recibido, porque apenas se recibió y se tiene ahí. Cuando hagamos lo que
#    hablamos del empaque, ahí sí va a decir empacado, porque ya lo
#    escaneamos, lo agregamos y lo metimos."
#
# Jorge lo había notado esa misma mañana sin saber qué era: "yo lo noté ahorita
# en la mañana, pero no sabía que estaba con él".
#
# No es cosmético. `ESTADOS_ORDEN` es `recibido_miami → empacado → …`, así que
# el paquete nacía un escalón más adelante de donde está de verdad: el
# dashboard contaba como empacado lo que sigue en la mesa, y `fecha_empacado`
# guardaba la hora de un paso que nadie dio.
class EtiquetarEstadoTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: tipo_envios(:cer).id, sucursal_recepcion_id: sucursales(:miami).id }
  end

  test "el paquete recien etiquetado queda recibido" do
    post etiquetar_url, params: { paquete: attrs }

    assert_equal "recibido_miami", Paquete.last.estado
  end

  test "no se marca una fecha de empacado que nadie hizo" do
    post etiquetar_url, params: { paquete: attrs }

    paquete = Paquete.last
    assert_nil paquete.fecha_empacado,
               "quedó fecha de empaque sin que exista todavía el módulo de empaque"
    assert_not_nil paquete.fecha_recibido_miami
  end

  test "queda registrado quien lo recibio" do
    post etiquetar_url, params: { paquete: attrs }

    assert_equal @user.id, Paquete.last.fecha_recibido_miami_by_user_id
  end

  test "las cajas de un split tambien quedan recibidas" do
    post etiquetar_url, params: { paquete: attrs.merge(cajas: { "1" => { peso: 5 }, "2" => { peso: 5 }, "3" => { peso: 5 } }) }

    cajas = Paquete.order(:id).last(3)
    assert_equal [ "recibido_miami" ] * 3, cajas.map(&:estado)
    assert_empty cajas.filter_map(&:fecha_empacado)
  end

  test "el paquete esperado de una pre-alerta pasa a recibido, no a empacado" do
    pap = pre_alertas(:activa).pre_alerta_paquetes.create!(
      tracking: "1Z999ESTADO0001", descripcion: "Cosas", fecha: Date.current
    )
    assert_equal "pre_alerta_estado", pap.reload.paquete.estado

    post etiquetar_url, params: { paquete: attrs.merge(tracking: "1Z999ESTADO0001") }

    assert_equal "recibido_miami", pap.reload.paquete.reload.estado
  end

  test "sacar un paquete del manifiesto lo devuelve a recibido" do
    # `empacado` ya no lo asigna ninguna pantalla. Devolver ahí dejaba el
    # paquete en un estado sin dueño: no lo produce nadie y no lo consume
    # ningún flujo.
    admin = users(:admin)
    post session_url, params: { email_address: admin.email_address, password: "password123" }
    manifiesto = manifiestos(:creado)
    paquete = paquetes(:empacado)
    paquete.update!(manifiesto: manifiesto)

    delete remove_paquete_manifiesto_url(manifiesto, paquete_id: paquete.id)

    assert_equal "recibido_miami", paquete.reload.estado
  end

  private

  def attrs
    {
      tracking: "EST#{SecureRandom.hex(4)}",
      cliente_id: clientes(:juan).id,
      descripcion: "Paquete de prueba",
      peso: 5
    }
  end
end
