require "test_helper"

# C31-11 · La «posible fecha de entrega» se fija al recibir, en días hábiles,
# y es la que el cliente lee en el correo y en su portal.
#
# Yusef, mirando el correo del sistema viejo: *"es días calendario y no días
# hábiles"*. El nuestro no daba fecha: *"será incluido en el próximo envío
# disponible"*.
class FechaPosibleEntregaAlRecibirTest < ActionDispatch::IntegrationTest
  # Viernes 16 de octubre de 2026, media mañana en Honduras. EXPRESS tarda 7
  # días hábiles: lun 19 a vie 23 son cinco, el sábado no es el último, y el
  # séptimo cae el martes 27.
  VIERNES = Time.zone.local(2026, 10, 16, 10, 0)
  MARTES_27 = Date.new(2026, 10, 27)

  setup do
    travel_to VIERNES
    @digitador = users(:digitador)
    post session_url, params: { email_address: @digitador.email_address, password: "password123" }
    post iniciar_sesion_etiquetar_url, params: { tipo_envio_id: tipo_envios(:express).id }
  end

  teardown { travel_back }

  test "etiquetar fija la fecha en días hábiles, aunque el paquete no tenga pre-alerta" do
    post etiquetar_url, params: { paquete: {
      tracking: "1ZFECHA0000001", cliente_id: clientes(:juan).id,
      peso: 2.0, descripcion: "Ropa"
    } }

    paquete = Paquete.find_by!(tracking: "1ZFECHA0000001")
    assert_equal MARTES_27, paquete.fecha_posible_entrega.to_date
  end

  test "en un envío de varias cajas la lleva cada caja, no solo la primera" do
    post etiquetar_url, params: { paquete: {
      tracking: "1ZFECHASPLIT01", cliente_id: clientes(:juan).id,
      peso: 5.0, descripcion: "Split",
      cajas: { "1" => { peso: 5 }, "2" => { peso: 5 }, "3" => { peso: 5 } },
      sucursal_id: sucursales(:miami).id
    } }

    cajas = Paquete.where(tracking: "1ZFECHASPLIT01")
    assert_equal 3, cajas.size
    assert_equal [ MARTES_27 ], cajas.map { |c| c.fecha_posible_entrega&.to_date }.uniq
  end

  test "un feriado la corre" do
    Feriado.create!(fecha: Date.new(2026, 10, 21), nombre: "Prueba")

    post etiquetar_url, params: { paquete: {
      tracking: "1ZFECHAFERIA01", cliente_id: clientes(:juan).id,
      peso: 2.0, descripcion: "Ropa"
    } }

    assert_equal Date.new(2026, 10, 28),
                 Paquete.find_by!(tracking: "1ZFECHAFERIA01").fecha_posible_entrega.to_date
  end

  # La gemela de /etiquetar: Entrega Personal manda el correo solo con
  # política, pero la fecha la lleva cada caja igual.
  test "entrega personal también la fija, en cada caja" do
    post entrega_personal_index_url, params: { paquete: {
      cliente_id: clientes(:juan).id, tipo_envio_id: tipo_envios(:express).id,
      proveedor_id: proveedores(:driver_entrega).id, sucursal_id: sucursales(:miami).id,
      peso: 3.0, descripcion: "Caja traida al mostrador",
      cajas: { "1" => { peso: 3 }, "2" => { peso: 4 } }
    } }

    cajas = Paquete.order(:id).last(2)
    assert_match(/\AEP-/, cajas.first.tracking)
    assert_equal [ MARTES_27 ], cajas.map { |c| c.fecha_posible_entrega&.to_date }.uniq
  end

  test "una fecha puesta a mano no se pisa" do
    paquete = paquetes(:recibido)
    a_mano = Time.zone.local(2026, 11, 20)
    paquete.update_columns(fecha_posible_entrega: a_mano, tipo_envio_id: tipo_envios(:express).id)

    paquete.fijar_fecha_posible_entrega

    assert_equal a_mano, paquete.reload.fecha_posible_entrega
  end

  test "un servicio sin días no promete fecha" do
    tipo_envios(:express).update!(dias_entrega: nil)

    post etiquetar_url, params: { paquete: {
      tracking: "1ZFECHASINDIA1", cliente_id: clientes(:juan).id,
      peso: 2.0, descripcion: "Ropa"
    } }

    assert_nil Paquete.find_by!(tracking: "1ZFECHASINDIA1").fecha_posible_entrega
  end

  # Antes la limpiaba el retroceso desde «disponible»: era la fecha de ese
  # estado. Ahora se fija al recibir, y borrarla le quitaría al cliente lo que
  # el correo le prometió.
  test "un retroceso de estado no borra la fecha" do
    paquete = paquetes(:recibido)
    paquete.update_columns(estado: "disponible_entrega", fecha_posible_entrega: VIERNES + 5.days)

    paquete.apply_retroceso_cleanup!("en_aduana")

    assert_not_nil paquete.fecha_posible_entrega
  end

  # La gemela: lo que ve el cliente en su portal y lo que ve SAC en admin.
  test "el cliente la ve en su pre-alerta, y admin en la gemela" do
    paquete = paquetes(:recibido)
    # `created_at` de ahora: el home del cliente muestra los cinco más nuevos.
    paquete.update_columns(fecha_posible_entrega: Time.zone.local(2026, 10, 27), created_at: Time.current)
    pre_alerta = pre_alertas(:recibida)

    get pre_alerta_path(pre_alerta)
    assert_response :success
    assert_match "Posible entrega", response.body
    assert_match "martes 27/10", response.body

    delete session_url
    post session_url, params: { email_address: clientes(:juan).email, password: "Cliente123!" }
    get cuenta_pre_alerta_path(pre_alerta)
    assert_response :success
    assert_match "Posible entrega", response.body
    assert_match "martes 27/10", response.body

    get cuenta_root_path
    assert_response :success
    assert_match "martes 27/10", response.body
  end
end
