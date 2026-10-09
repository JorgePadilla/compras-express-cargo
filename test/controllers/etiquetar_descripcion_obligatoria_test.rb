require "test_helper"

# C30-03 (responde RP-74). Yusef, 2026-10-09, recorriendo staging:
#
#   > "en etiqueta puse el tracking, el cliente, y la descripción me la está
#   >  dejando dejar vacía … ok, descripción tiene que estar llena."
#
# Hasta acá el contenido era obligatorio solo en Entrega Personal (#306). Ahora
# lo es en todo lo que se recibe por /etiquetar, de cualquier servicio — sin
# trabar los paquetes viejos que no lo tienen, ni los otros caminos que nacen
# legítimamente sin él (pre-alerta, importados, /paquetes).
class EtiquetarDescripcionObligatoriaTest < ActionDispatch::IntegrationTest
  # Lo que manda Turbo de verdad: acepta stream, y si no, la página entera
  # (que es como vuelve un 422).
  TURBO = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze

  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @cer = tipo_envios(:cer)
    @miami = sucursales(:miami)
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: @cer.id, sucursal_recepcion_id: @miami.id }
  end

  # ── Al recibir ────────────────────────────────────────────────────────

  test "sin descripción no se graba, y el error dice qué falta" do
    assert_no_difference "Paquete.count" do
      post etiquetar_url, params: { paquete: {
        tracking: "1ZC3003SINDESC1", cliente_id: clientes(:juan).id, peso: 3, descripcion: ""
      } }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "hay que decir qué es (Contenido)"
  end

  test "con descripción se graba como siempre" do
    assert_difference "Paquete.count", 1 do
      post etiquetar_url, params: { paquete: {
        tracking: "1ZC3003CONDESC1", cliente_id: clientes(:juan).id, peso: 3, descripcion: "Ropa"
      } }
    end
    assert_equal "Ropa", Paquete.find_by(tracking: "1ZC3003CONDESC1").descripcion
  end

  test "solo espacios no cuenta como descripción" do
    assert_no_difference "Paquete.count" do
      post etiquetar_url, params: { paquete: {
        tracking: "1ZC3003ESPACIOS", cliente_id: clientes(:juan).id, descripcion: "   "
      } }
    end
    assert_response :unprocessable_entity
  end

  test "aplica a todos los servicios, no solo a EP: un CEM tampoco pasa" do
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: tipo_envios(:cem).id, sucursal_recepcion_id: @miami.id }

    assert_no_difference "Paquete.count" do
      post etiquetar_url, params: { paquete: {
        tracking: "1ZC3003CEMSIN01", cliente_id: clientes(:juan).id, peso: 3
      } }
    end
    assert_response :unprocessable_entity
  end

  test "un envío de varias cajas tampoco se graba sin descripción" do
    # `crear_split!` arma y guarda las cajas por su cuenta: si la bandera no
    # viajara en los `attrs`, las N cajas se colaban.
    assert_no_difference "Paquete.count" do
      post etiquetar_url, params: { etiquetas: 3, paquete: {
        tracking: "1ZC3003SPLITSIN", cliente_id: clientes(:juan).id
      } }
    end
    assert_response :unprocessable_entity
    assert_includes response.body, "hay que decir qué es (Contenido)"
  end

  test "el esperado de una pre-alerta sin contenido no se recibe vacío" do
    # El caso más común de Miami. El esperado ya está grabado, así que el
    # `new_record? || descripcion_changed?` de EP lo dejaba pasar.
    esperado = esperado_sin_descripcion("1ZC3003ESPERADO")

    post etiquetar_url, params: { paquete: {
      tracking: esperado.tracking, cliente_id: clientes(:juan).id, peso: 3, descripcion: ""
    } }

    assert_response :unprocessable_entity
    assert_equal "pre_alerta_estado", esperado.reload.estado, "no se tiene que haber recibido"
  end

  test "el esperado se recibe cuando el operario le pone el contenido" do
    esperado = esperado_sin_descripcion("1ZC3003ESPERAD2")

    post etiquetar_url, params: { paquete: {
      tracking: esperado.tracking, cliente_id: clientes(:juan).id, peso: 3, descripcion: "Zapatos"
    } }

    esperado.reload
    assert_equal "recibido_miami", esperado.estado
    assert_equal "Zapatos", esperado.descripcion
  end

  test "el esperado de una pre-alerta que ya traía contenido pasa sin teclearlo otra vez" do
    pap = pre_alertas(:activa).pre_alerta_paquetes.create!(
      tracking: "1ZC3003ESPERAD3", descripcion: "Perfumes", fecha: Date.current
    )
    esperado = pap.reload.paquete
    assert_equal "Perfumes", esperado.descripcion
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: pre_alertas(:activa).tipo_envio_id, sucursal_recepcion_id: @miami.id }

    # El formulario sí la manda: el JS la auto-llena desde la pre-alerta. Acá
    # se prueba que el servidor no la pida dos veces si no vino.
    post etiquetar_url, params: { paquete: {
      tracking: esperado.tracking, cliente_id: clientes(:juan).id, peso: 3
    } }

    assert_equal "recibido_miami", esperado.reload.estado
  end

  # ── Al actualizar ─────────────────────────────────────────────────────

  test "un paquete viejo sin descripción se sigue pudiendo corregir de peso" do
    viejo = paquete_sin_descripcion

    patch actualizar_etiquetar_url(viejo), params: { paquete: { peso: 7 } }, headers: TURBO

    assert_response :success
    assert_equal 7, viejo.reload.peso.to_i
  end

  test "al actualizar, vaciar la descripción es un error" do
    paquete = paquete_sin_descripcion
    paquete.update_column(:descripcion, "Libros")

    patch actualizar_etiquetar_url(paquete), params: { paquete: { descripcion: "", peso: 9 } }, headers: TURBO

    assert_response :unprocessable_entity
    assert_equal "Libros", paquete.reload.descripcion
    assert_not_equal 9, paquete.peso.to_i, "no se guarda nada a medias"
  end

  # ── La pantalla ───────────────────────────────────────────────────────

  test "al dar de alta el campo lleva required, como el tracking" do
    get etiquetar_url
    assert_select "textarea#paquete_descripcion[required]"
  end

  test "al actualizar uno viejo sin descripción el campo no la exige; si ya tenía, sí" do
    viejo = paquete_sin_descripcion
    get etiquetar_url(paquete_id: viejo.id)
    assert_select "textarea#paquete_descripcion"
    assert_select "textarea#paquete_descripcion[required]", count: 0

    viejo.update_column(:descripcion, "Libros")
    get etiquetar_url(paquete_id: viejo.id)
    assert_select "textarea#paquete_descripcion[required]"
  end

  # ── Los otros caminos no cambian ──────────────────────────────────────

  test "fuera de /etiquetar un paquete que no es EP se sigue grabando sin descripción" do
    # Importados, esperados de pre-alerta, cajas de `ajustar_split!`, /paquetes:
    # ninguno pone la bandera.
    assert paquete_sin_descripcion.persisted?
  end

  test "EP sigue exigiéndola sin bandera, como antes" do
    ep = Paquete.new(cliente: clientes(:juan), tipo_envio: @cer, estado: "recibido_miami",
                     proveedor: proveedores(:driver_entrega), user: @user)
    assert ep.entrega_personal?
    assert_not ep.valid?
    assert ep.errors[:descripcion].any?
  end

  private

  def paquete_sin_descripcion
    Paquete.create!(
      tracking: "VIEJO#{SecureRandom.hex(4)}", cliente: clientes(:juan), tipo_envio: @cer,
      sucursal_recepcion: @miami, estado: "recibido_miami", descripcion: nil, peso: 2, user: @user
    )
  end

  def esperado_sin_descripcion(tracking)
    pap = pre_alertas(:activa).pre_alerta_paquetes.create!(tracking: tracking, descripcion: "x", fecha: Date.current)
    esperado = pap.reload.paquete
    # La pre-alerta exige la suya; lo que se prueba es el esperado que quedó
    # sin contenido (uno de antes, o uno al que se lo borraron).
    esperado.update_column(:descripcion, nil)
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: pre_alertas(:activa).tipo_envio_id, sucursal_recepcion_id: @miami.id }
    esperado
  end
end
