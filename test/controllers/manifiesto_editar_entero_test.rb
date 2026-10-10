require "test_helper"

# PR-C30.15 · «Editar» edita el manifiesto **en su ficha**, no en otra pantalla.
#
# Jorge, 2026-10-10, después de PR-C30.14 (que había hecho de /edit el
# manifiesto entero): *"it really don't make sense pressing editar sends me
# here, I want to edit the current view plus all what is in the manifiesto,
# something like this view /manifiestos/24"*.
#
# Así que la tarjeta «Detalles del Manifiesto» es un Turbo Frame que se da
# vuelta a formulario; /edit solo contesta adentro de ese frame (o manda a la
# ficha con `?editar=1`). Y de PR-C30.14 sigue: lo de San Pedro en el
# formulario, los recibidos se reabren (solo el oficial) y lo que San Pedro ya
# hizo se cuida paquete por paquete (`Manifiesto#sacar!`, `#meter!`).
class ManifiestoEditarEnteroTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze
  FRAME = { "Turbo-Frame" => "manifiesto-detalles" }.freeze
  # Lo que manda un formulario de Turbo adentro del frame.
  FORM_EN_EL_FRAME = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml",
                       "Turbo-Frame" => "manifiesto-detalles" }.freeze

  setup do
    @supervisor = users(:supervisor_miami)
    @digitador = users(:digitador)
    @cer = tipo_envios(:cer)

    @abierto = manifiestos(:creado)
    @abierto.update!(sucursal_entrega: sucursales(:zeron_sps))
    @adentro = paquetes(:empacado)
    @adentro.update_columns(tipo_envio_id: @cer.id)
    @caja = @abierto.cajas.create!(tamano_caja: tamano_cajas(:mediana), peso: 10, user: @supervisor)
    @abierto.meter!(@adentro, user: @supervisor, caja_manifiesto: @caja)
  end

  # ── «Editar» da vuelta la tarjeta, en el lugar ──────────────────────────

  test "adentro del frame, edit devuelve la tarjeta en formulario: Miami, San Pedro, Cancelar y Guardar" do
    ingresar(@supervisor)
    get edit_manifiesto_url(@abierto), headers: FRAME

    assert_response :success
    assert_select "turbo-frame#manifiesto-detalles form[data-teclas-alcance][action=?]", manifiesto_path(@abierto) do
      assert_select "select[name='manifiesto[consignatario_id]']"
      assert_select "input[name='manifiesto[tipo_envio_ids][]']"
      assert_select "input[name='manifiesto[fecha_aduana]']"
      assert_select "[data-controller='guias-repetidor'] input[name^='manifiesto[guias_attributes]']"
      assert_select "a[href=?][data-shortcut='F2']", manifiesto_path(@abierto), text: /Cancelar/
      assert_select "button[type='submit'][data-shortcut='F8']", text: /Guardar/
      assert_select "#manifiesto-detalles-paquetes", text: @abierto.reload.cantidad_paquetes.to_s
      assert_select "#manifiesto-detalles-peso"
    end
    assert_select "h2", text: "Casas del manifiesto", count: 0, message: "el frame es la tarjeta sola"
  end

  test "edit pedido entero va a la ficha con la tarjeta abierta (el lápiz de la lista)" do
    ingresar(@supervisor)
    get edit_manifiesto_url(@abierto)
    assert_redirected_to manifiesto_url(@abierto, editar: 1)

    follow_redirect!
    assert_select "turbo-frame#manifiesto-detalles form[data-teclas-alcance]"
    assert_contenido_editable
  end

  test "la ficha sin ?editar trae la tarjeta de solo lectura, con sus ids de paquetes y peso" do
    ingresar(@supervisor)
    get manifiesto_url(@abierto)

    assert_select "turbo-frame#manifiesto-detalles" do
      assert_select "form", count: 0
      assert_select "#manifiesto-detalles-paquetes", text: @abierto.reload.cantidad_paquetes.to_s
      assert_select "#manifiesto-detalles-peso", text: /lbs/
    end
    assert_select "#manifiesto-contenido"
    assert_select "#manifiesto-acciones-arriba form[action=?]", finalizar_manifiesto_path(@abierto)
    assert_contenido_editable
  end

  # «Cancelar» pide la ficha adentro del frame.
  test "la ficha pedida desde el frame es la tarjeta de solo lectura, sola" do
    ingresar(@supervisor)
    get manifiesto_url(@abierto), headers: FRAME

    assert_response :success
    assert_select "turbo-frame#manifiesto-detalles"
    assert_select "form", count: 0
    assert_select "#manifiesto-contenido", count: 0
  end

  # ── Un solo «Editar» ────────────────────────────────────────────────────

  test "abierto: «Editar» (F6) apunta al frame de la tarjeta, también para el digitador" do
    [ @supervisor, @digitador ].each do |user|
      ingresar(user)
      get manifiesto_url(@abierto)
      assert_select "a[href=?][data-turbo-frame='manifiesto-detalles'][data-shortcut='F6']",
                    edit_manifiesto_path(@abierto), text: /Editar/
      assert_select "[data-shortcut='F6']", count: 1
    end
  end

  test "recibido y cerrado, supervisor de Miami o de Pre-Factura: el «Editar» de arriba abre el candado; el cartel no tiene botón" do
    recibir!

    [ @supervisor, users(:supervisor_prefactura) ].each do |user|
      ingresar(user)
      get manifiesto_url(@abierto)

      assert_select "form[action=?] button[data-shortcut='F6'][data-turbo-confirm]",
                    abrir_edicion_manifiesto_path(@abierto), text: /Editar/
      assert_select "[data-shortcut='F6']", count: 1
      assert_select "a[href=?]", edit_manifiesto_path(@abierto), count: 0
      assert_select "[data-candado='cerrado']", count: 2 # arriba y abajo
      assert_select "[data-candado='cerrado'] button", count: 0
      assert_select "[data-candado='cerrado'] form", count: 0
      assert_select "[data-candado='cerrado']", text: /«Editar» arriba lo abre/
    end
  end

  test "abrir el candado aterriza en la ficha con la tarjeta y lo de adentro editables" do
    recibir!
    sup_pf = users(:supervisor_prefactura)
    ingresar(sup_pf)

    patch abrir_edicion_manifiesto_url(@abierto)
    assert_redirected_to manifiesto_url(@abierto, editar: 1)
    assert @abierto.reload.edicion_abierta?, "lo abrió"
    assert_equal sup_pf, @abierto.edicion_abierta_por

    follow_redirect!
    assert_select "turbo-frame#manifiesto-detalles form[data-teclas-alcance]"
    assert_select "[data-candado='abierto'] form[action=?] button", cerrar_edicion_manifiesto_path(@abierto),
                  text: /Cerrar edición/
    assert_contenido_editable
    # Con el candado abierto, el de arriba vuelve a ser el del frame.
    assert_select "a[href=?][data-turbo-frame='manifiesto-detalles'][data-shortcut='F6']", edit_manifiesto_path(@abierto)

    patch cerrar_edicion_manifiesto_url(@abierto)
    assert_redirected_to manifiesto_url(@abierto)
    assert_not @abierto.reload.edicion_abierta?
  end

  test "el digitador no ve «Editar» en uno recibido, no lo abre y no edita; el cajero ni entra" do
    recibir!
    ingresar(@digitador)

    get manifiesto_url(@abierto)
    assert_select "[data-shortcut='F6']", count: 0
    assert_select "a[href=?]", edit_manifiesto_path(@abierto), count: 0
    assert_select "form[action=?]", abrir_edicion_manifiesto_path(@abierto), count: 0
    assert_select "[data-candado='cerrado']", text: /supervisor \(Miami o Pre-Factura\) aprieta «Editar»/

    get manifiesto_url(@abierto, editar: 1)
    assert_select "turbo-frame#manifiesto-detalles form", count: 0

    get edit_manifiesto_url(@abierto)
    assert_redirected_to manifiesto_url(@abierto)

    patch manifiesto_url(@abierto), params: { manifiesto: { es_prioridad: "1", guias_attributes: { "0" => { numero: "X1" } } } }
    assert_match(/finalizado/, flash[:alert])
    assert_not @abierto.reload.es_prioridad?
    assert_empty @abierto.numeros_de_guia

    tarde = paquetes(:recibido)
    post add_paquete_manifiesto_url(@abierto), params: { paquete_id: tarde.id }, headers: TURBO
    assert_response :forbidden
    assert_nil tarde.reload.manifiesto_id

    patch abrir_edicion_manifiesto_url(@abierto)
    assert_not @abierto.reload.edicion_abierta?
    assert_match(/supervisor \(Miami o Pre-Factura\)/, flash[:alert])

    ingresar(users(:cajero))
    get manifiesto_url(@abierto)
    assert_redirected_to root_path
  end

  # La decisión de PR-C30.15: en uno oficial finalizado, el encabezado también
  # espera al candado. *"Que presionen el botón."* Hasta acá `update` le
  # aceptaba el encabezado al supervisor sin abrir nada.
  test "cerrado: ni el supervisor guarda el encabezado sin abrir el candado" do
    recibir!
    ingresar(@supervisor)

    get edit_manifiesto_url(@abierto), headers: FRAME
    assert_select "form[data-teclas-alcance]", count: 0

    patch manifiesto_url(@abierto), params: { manifiesto: { es_prioridad: "1" } }
    assert_redirected_to manifiesto_url(@abierto)
    assert_match "aprieta «Editar»", flash[:alert]
    assert_not @abierto.reload.es_prioridad?

    patch manifiesto_url(@abierto), params: { manifiesto: { es_prioridad: "1" } }, headers: FORM_EN_EL_FRAME
    assert_response :forbidden
    assert_match %r{<turbo-stream action="refresh"}, response.body
    assert_not @abierto.reload.es_prioridad?
  end

  # El interno no se reabre (`reabrible?`), y su encabezado lo corrige directo
  # quien abre el candado, como en C21-06.
  test "interno finalizado: el supervisor corrige el encabezado desde el frame; el digitador no" do
    @abierto.update_columns(tipo: "interno", estado: "enviado")
    assert_not @abierto.reload.reabrible?

    ingresar(@supervisor)
    get manifiesto_url(@abierto)
    assert_select "a[href=?][data-turbo-frame='manifiesto-detalles'][data-shortcut='F6']", edit_manifiesto_path(@abierto)
    patch manifiesto_url(@abierto), params: { manifiesto: { es_prioridad: "1" } }, headers: FORM_EN_EL_FRAME
    assert @abierto.reload.es_prioridad?

    ingresar(@digitador)
    get manifiesto_url(@abierto)
    assert_select "[data-shortcut='F6']", count: 0
    patch manifiesto_url(@abierto), params: { manifiesto: { es_prioridad: "0" } }
    assert @abierto.reload.es_prioridad?
  end

  # ── Guardar ─────────────────────────────────────────────────────────────

  test "guardar desde el frame cambia la tarjeta a solo lectura, refresca los cierres y lo de adentro, y avisa" do
    consignatario = Consignatario.create!(nombre: "KARSAM TEST", activo: true)
    ingresar(@supervisor)

    patch manifiesto_url(@abierto), params: { manifiesto: { consignatario_id: consignatario.id } },
                                    headers: FORM_EN_EL_FRAME

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    tarjeta = stream(response.body, "replace", "manifiesto-detalles")
    assert tarjeta, "la tarjeta se reemplaza (el frame vive adentro del partial)"
    assert_includes tarjeta, %(<turbo-frame class="block" id="manifiesto-detalles")
    assert_no_match(/<form/, tarjeta, "vuelve de solo lectura")
    assert_includes tarjeta, "KARSAM TEST"
    assert stream(response.body, "update", "manifiesto-acciones-arriba")
    assert stream(response.body, "update", "manifiesto-acciones-abajo")
    assert stream(response.body, "update", "manifiesto-contenido"), "«Empacar sin escanear (N)» depende de los tipos"
    assert_match(/Manifiesto actualizado exitosamente/, stream(response.body, "prepend", "flash-messages"))

    @abierto.reload
    assert_equal consignatario.id, @abierto.consignatario_id
    assert @abierto.creado?, "guardar no finaliza"
  end

  # `A7-07` · Oficial o interno se elige al crear. La tarjeta no lo manda, y un
  # PATCH armado a mano tampoco lo cambia: el número y la carga ya siguieron
  # las reglas de su tipo.
  test "guardar no cambia el tipo del manifiesto aunque el PATCH lo traiga" do
    assert @abierto.tipo_oficial?
    ingresar(@supervisor)

    patch manifiesto_url(@abierto), params: { manifiesto: { tipo: "interno", es_prioridad: "1" } },
                                    headers: FORM_EN_EL_FRAME

    assert_response :success
    @abierto.reload
    assert @abierto.tipo_oficial?, "el tipo no se cambia después de crear"
    assert @abierto.es_prioridad?, "lo demás sí se guarda"
  end

  test "un error del formulario vuelve a pintar la tarjeta en formulario, 422 y html, adentro del frame" do
    ingresar(@supervisor)
    patch manifiesto_url(@abierto), params: { manifiesto: { fecha_aduana: Date.tomorrow.iso8601 } },
                                    headers: FORM_EN_EL_FRAME

    assert_response :unprocessable_entity
    assert_equal "text/html", response.media_type
    assert_select "turbo-frame#manifiesto-detalles form[data-teclas-alcance]" do
      assert_select "li", text: /fecha futura/
    end
    assert_nil @abierto.reload.fecha_aduana
  end

  test "un error sin Turbo pinta la ficha entera con la tarjeta abierta" do
    ingresar(@supervisor)
    patch manifiesto_url(@abierto), params: { manifiesto: { fecha_aduana: Date.tomorrow.iso8601 } }

    assert_response :unprocessable_entity
    assert_select "turbo-frame#manifiesto-detalles form[data-teclas-alcance] li", text: /fecha futura/
    assert_contenido_editable
  end

  test "con el candado abierto, el supervisor guarda guías y fecha de uno recibido, y queda quién la puso" do
    recibir!
    @abierto.abrir_edicion!(@supervisor)
    ingresar(@supervisor)

    patch manifiesto_url(@abierto), params: { manifiesto: {
      fecha_aduana: Date.yesterday.iso8601,
      guias_attributes: { "0" => { numero: "286441-1" }, "1" => { numero: "286441-2" } }
    } }

    assert_redirected_to manifiesto_url(@abierto)
    @abierto.reload
    assert_equal [ "286441-1", "286441-2" ], @abierto.numeros_de_guia
    assert_equal Date.yesterday, @abierto.fecha_aduana.to_date
    assert_equal @supervisor.iniciales_display, @abierto.recibido_hn_por
  end

  # La columna guarda la hora del cierre de la recepción; el formulario manda
  # el día. Guardar el encabezado sin tocar la fecha no es «cambiarla».
  test "guardar el encabezado sin tocar la fecha no la cambia ni cambia quién la puso" do
    recibir!
    @abierto.abrir_edicion!(@supervisor)
    @abierto.update_columns(recibido_hn_por: "SPS")
    antes = @abierto.reload.fecha_aduana
    ingresar(@supervisor)

    patch manifiesto_url(@abierto), params: { manifiesto: {
      es_prioridad: "1", fecha_aduana: antes.to_date.iso8601
    } }

    @abierto.reload
    assert @abierto.es_prioridad?
    assert_equal antes.to_i, @abierto.fecha_aduana.to_i
    assert_equal "SPS", @abierto.recibido_hn_por
  end

  # ── El escaneo no pisa la tarjeta ───────────────────────────────────────

  test "agregar un paquete sube paquetes y peso por su id, sin reemplazar la tarjeta" do
    tarde = paquetes(:recibido)
    tarde.tareas.update_all(estado: "realizada")
    tarde.update_columns(tipo_envio_id: @cer.id, sucursal_id: sucursales(:zeron_sps).id)
    ingresar(@supervisor)

    post add_paquete_manifiesto_url(@abierto), params: { paquete_id: tarde.id }, headers: TURBO

    assert_response :success
    assert_equal @abierto.id, tarde.reload.manifiesto_id
    assert_equal @abierto.reload.cantidad_paquetes.to_s,
                 stream(response.body, "update", "manifiesto-detalles-paquetes").to_s[%r{<template>(.*)</template>}m, 1]
    assert_match(/lbs/, stream(response.body, "update", "manifiesto-detalles-peso"))
    assert_nil stream(response.body, "replace", "manifiesto-detalles"), "una tarjeta abierta perdería lo tecleado"
    assert_no_match(/target="manifiesto-contenido"/, response.body, "ni lo de adentro: se llevaría la pistola")
  end

  # ── Las casas ───────────────────────────────────────────────────────────

  test "las tres acciones de cada caja van juntas y el basurero no es un bloque rojo" do
    ingresar(@supervisor)
    get manifiesto_url(@abierto)

    assert_select "tr[data-caja=?] td div.inline-flex", @caja.letra do
      assert_select "[aria-label=?]", "Editar la caja #{@caja.letra}"
      assert_select "[aria-label=?]", "Imprimir la etiqueta de la caja #{@caja.letra}"
      assert_select "form.contents button[aria-label=?]", "Eliminar caja #{@caja.letra}"
    end
    assert_select "button[aria-label=?].bg-red-600", "Eliminar caja #{@caja.letra}", count: 0
  end

  # PR-C30.15 · Sin /edit no hay otra pantalla a la que volver: las cajas
  # vuelven a la ficha, venga de donde venga el pedido.
  test "una caja agregada vuelve a la ficha, y la 4×6 con volver=1" do
    ingresar(@supervisor)
    datos = { caja_manifiesto: { tamano_caja_id: tamano_cajas(:mediana).id, peso: 4 } }

    post manifiesto_cajas_url(@abierto), params: datos, headers: { "Referer" => edit_manifiesto_url(@abierto) }
    assert_redirected_to manifiesto_path(@abierto)

    post manifiesto_cajas_url(@abierto), params: datos.merge(print: "true")
    assert_redirected_to(/volver=1/)
  end

  # ── Sacar lo que no se puede ────────────────────────────────────────────

  test "sacar uno con medición de uno recibido: no sale y se avisa" do
    recibir!
    @abierto.abrir_edicion!(@supervisor)
    @adentro.update_columns(medicion_sesion: "tanda-1")
    ingresar(@supervisor)

    delete remove_paquete_manifiesto_url(@abierto, paquete_id: @adentro.id), headers: TURBO

    # 422 y no 200: el modal de «Eliminar paquetes» cuenta como sacado lo que vuelve bien.
    assert_response :unprocessable_entity
    assert_match "ya se midió", response.body
    assert_equal @abierto.id, @adentro.reload.manifiesto_id

    post escanear_para_quitar_manifiesto_url(@abierto), params: { codigo: @adentro.tracking }, as: :json
    assert_equal "no_se_saca", response.parsed_body["resultado"]
    assert_match "ya se midió", response.parsed_body["mensaje"]
  end

  private

  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  # Finaliza en Miami y Honduras lo recibe entero (caja escaneada, recepción
  # cerrada). Es el 21 de Jorge.
  def recibir!
    assert_not FinalizarManifiesto.new(@abierto, user: @supervisor).call.bloqueado?
    recepcion = RecibirManifiesto.new(@abierto.reload, user: @supervisor)
    recepcion.recibir_caja!(@caja)
    recepcion.finalizar!
    assert @abierto.reload.recibido?
  end

  # Un `<turbo-stream>` de la respuesta, entero, por acción y target. Se corta
  # a mano porque `assert_select` no entra a los `<template>`.
  def stream(body, accion, target)
    body[%r{<turbo-stream action="#{accion}" target="#{target}">.*?</turbo-stream>}m]
  end

  def assert_contenido_editable
    assert_select "h2", text: "Casas del manifiesto"
    assert_select "form[action=?]", manifiesto_cajas_path(@abierto)
    assert_select "h2", text: "Agregar paquetes"
    assert_select "#buscar_paquete"
    assert_select "[data-controller~='manifiesto-quitar']"
    assert_select "turbo-frame#manifiesto-paquetes", text: /#{Regexp.escape(@adentro.tracking)}/
  end
end
