require "test_helper"

# PR-C6.21: el escaneo de punta a punta — lo que `/etiquetar` le pregunta al
# servidor cuando la pistola dispara, y qué pasa al guardar.
#
# El caso que Yusef mostró en vivo: la etiqueta de USPS lleva el código
# completo (`420` + ZIP + servicio + tracking) y el cliente pre-alerta solo la
# cola, que es la que le muestra el correo.
#
#   "El tracking de USPS **solo es desde donde dice 92**... esto es lo que el
#    cliente recibe de tracking y **esto es lo que le escanea el sistema**."
#
# Con el match exacto, ese escaneo no encontraba nada: ni el paquete esperado
# ni su pre-alerta. Miami grababa un paquete nuevo al lado del esperado, sin
# cliente y bajo el tipo de envío de la sesión — que es lo que después se
# factura mal.
class EtiquetarEscaneoTest < ActionDispatch::IntegrationTest
  ESCANEADO_USPS = "420331439261091390000806743500382574".freeze
  TRACKING_USPS  = "9261091390000806743500382574".freeze

  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  # --- check_tracking: lo que consulta la pistola ---

  test "el codigo largo de la pistola encuentra el paquete del cliente" do
    paquete = crear_paquete(tracking: TRACKING_USPS)

    get check_tracking_paquetes_url, params: { tracking: ESCANEADO_USPS }
    data = JSON.parse(response.body)

    assert data["exists"], "el escaneo de USPS no encontró el paquete"
    assert_equal paquete.id, data["existing_paquete_id"]
  end

  test "el duplicado se sufija sobre el tracking guardado, no sobre el escaneo" do
    # Si `tracking_base` fuera el escaneo, "es duplicado real" crearía un
    # paquete con un tracking que el cliente nunca vio y que no existe en
    # ningún carrier.
    crear_paquete(tracking: TRACKING_USPS)

    get check_tracking_paquetes_url, params: { tracking: ESCANEADO_USPS }
    data = JSON.parse(response.body)

    assert_equal TRACKING_USPS, data["tracking_base"]
    assert_equal "#{TRACKING_USPS}#{data['next_suffix']}", data["next_tracking"]
  end

  test "encuentra por el tracking secundario" do
    paquete = crear_paquete(tracking: "TBA000000000009", tracking_secundario: "1ZSEC00XX0123456789")

    get check_tracking_paquetes_url, params: { tracking: "1ZSEC00XX0123456789" }
    data = JSON.parse(response.body)

    assert data["exists"], "no buscó en el tracking secundario"
    assert_equal paquete.id, data["existing_paquete_id"]
  end

  test "el codigo largo tambien encuentra la pre-alerta" do
    # Este es el que más duele: sin la pre-alerta no se auto-llena el cliente
    # y no salta el aviso de tipo de envío distinto.
    pa = pre_alertas(:activa)
    pa.pre_alerta_paquetes.create!(tracking: TRACKING_USPS, descripcion: "Cosas", fecha: Date.current)

    get check_tracking_paquetes_url, params: { tracking: ESCANEADO_USPS }
    data = JSON.parse(response.body)

    assert data["pre_alerta_match"], "el escaneo de USPS perdió la pre-alerta"
    assert_equal pa.cliente.id, data["cliente_id"]
  end

  test "el codigo largo encuentra una pre-alerta sin paquete esperado" do
    # `crear_paquete_esperado` le crea un paquete a cada PAP nuevo, así que el
    # test de arriba pasa igual aunque la consulta de la pre-alerta esté rota:
    # la encuentra de rebote, por el `paquete_id` del esperado.
    #
    # Este llega por el otro lado — un PAP **sin vincular**, que es lo que hay
    # en las filas viejas y en las que perdieron su paquete. Ahí no hay rebote
    # que valga: si la consulta de la pre-alerta no tolera el código largo, el
    # operario se queda sin cliente y sin aviso de tipo de envío.
    pap = pre_alerta_paquetes(:pap_sin_vincular)
    assert_nil pap.paquete_id, "la fixture dejó de estar sin vincular"
    escaneado = "4203314#{pap.tracking}"

    get check_tracking_paquetes_url, params: { tracking: escaneado }
    data = JSON.parse(response.body)

    assert_not data["exists"], "no debería haber paquete para este escaneo"
    assert data["pre_alerta_match"], "el escaneo largo perdió la pre-alerta sin vincular"
    assert_equal pap.pre_alerta.cliente_id, data["cliente_id"]
  end

  test "un escaneo que no es de nadie sigue sin encontrar nada" do
    get check_tracking_paquetes_url, params: { tracking: "420331439999999999999999999999999999" }
    data = JSON.parse(response.body)

    assert_not data["exists"]
    assert_not data["pre_alerta_match"]
  end

  # --- guardar: la reconciliación con el paquete esperado ---

  test "escanear el codigo largo no duplica el paquete esperado" do
    pa = pre_alertas(:activa)
    pap = pa.pre_alerta_paquetes.create!(tracking: TRACKING_USPS, descripcion: "Cosas", fecha: Date.current)
    esperado = pap.reload.paquete
    assert_equal "pre_alerta_estado", esperado.estado

    iniciar_sesion
    assert_no_difference "Paquete.count" do
      post etiquetar_url, params: { paquete: attrs.merge(tracking: ESCANEADO_USPS) }
    end

    assert_equal esperado.id, Paquete.order(:updated_at).last.id
  end

  test "el tracking del cliente se conserva y el escaneo queda de secundario" do
    # El cliente tiene en la mano el código corto — es por el que va a
    # preguntar. El largo es un detalle de la pistola, pero tiene que quedar
    # buscable para el próximo escaneo.
    pa = pre_alertas(:activa)
    pap = pa.pre_alerta_paquetes.create!(tracking: TRACKING_USPS, descripcion: "Cosas", fecha: Date.current)

    iniciar_sesion
    post etiquetar_url, params: { paquete: attrs.merge(tracking: ESCANEADO_USPS) }

    paquete = pap.reload.paquete.reload
    assert_equal TRACKING_USPS,  paquete.tracking
    assert_equal ESCANEADO_USPS, paquete.tracking_secundario
  end

  test "un secundario que el operario escribio no se pisa" do
    pa = pre_alertas(:activa)
    pap = pa.pre_alerta_paquetes.create!(tracking: TRACKING_USPS, descripcion: "Cosas", fecha: Date.current)

    iniciar_sesion
    post etiquetar_url, params: {
      paquete: attrs.merge(tracking: ESCANEADO_USPS, tracking_secundario: "1ZMIO00XX0123456789")
    }

    assert_equal "1ZMIO00XX0123456789", pap.reload.paquete.reload.tracking_secundario
  end

  test "el escaneo exacto se sigue reconciliando como siempre" do
    pa = pre_alertas(:activa)
    pap = pa.pre_alerta_paquetes.create!(tracking: TRACKING_USPS, descripcion: "Cosas", fecha: Date.current)

    iniciar_sesion
    assert_no_difference "Paquete.count" do
      post etiquetar_url, params: { paquete: attrs.merge(tracking: TRACKING_USPS) }
    end

    paquete = pap.reload.paquete.reload
    assert_equal TRACKING_USPS, paquete.tracking
    assert_nil paquete.tracking_secundario.presence,
               "sin escaneo distinto no hay nada que guardar de secundario"
  end

  private

  def iniciar_sesion
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: pre_alertas(:activa).tipo_envio_id,
                   sucursal_recepcion_id: sucursales(:miami).id }
  end

  def attrs
    { cliente_id: clientes(:juan).id, descripcion: "Paquete de prueba", peso: 5 }
  end

  def crear_paquete(extra)
    Paquete.create!({
      cliente: clientes(:juan),
      tipo_envio: tipo_envios(:cer),
      descripcion: "Paquete de prueba",
      peso: 5,
      estado: "recibido_miami",
      user: @user
    }.merge(extra))
  end
end
