require "test_helper"

# PR-C30.14 · «Editar manifiesto» edita el manifiesto **entero**.
#
# Jorge, 2026-10-10, en /manifiestos/21/edit (un recibido): *"esta pantalla de
# editar me debería dejar editar todo lo que está en el manifiesto, pero solo
# está la parte de Miami, prioridad y tipo de envío"* · *"editar de manifiesto
# debería ser muy parecido a /manifiestos/22"*.
#
# Y sus decisiones: /edit lleva también lo de San Pedro y las casas y los
# paquetes; los recibidos se reabren (solo el oficial); y lo que San Pedro ya
# hizo se cuida paquete por paquete (`Manifiesto#sacar!`, `#meter!`).
class ManifiestoEditarEnteroTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

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

  # ── La pantalla ─────────────────────────────────────────────────────────

  test "abierto: /edit tiene las casas, agregar paquetes y lo de San Pedro, para admin y supervisor" do
    [ users(:admin), @supervisor ].each do |user|
      ingresar(user)
      get edit_manifiesto_url(@abierto)

      assert_response :success
      assert_contenido_editable
      assert_select "input[name='manifiesto[fecha_aduana]']"
      assert_select "[data-controller='guias-repetidor'] input[name^='manifiesto[guias_attributes]']"
    end
  end

  test "recibido y reabierto: /edit también, con el cartel de abierto" do
    recibir!
    @abierto.abrir_edicion!(@supervisor)

    [ users(:admin), @supervisor ].each do |user|
      ingresar(user)
      get edit_manifiesto_url(@abierto)

      assert_response :success
      assert_contenido_editable
      assert_select "[data-candado='abierto']"
      assert_select "form[action=?] button", cerrar_edicion_manifiesto_path(@abierto), text: /Cerrar edición/
      assert_select "input[name='manifiesto[fecha_aduana]']"
    end
  end

  test "recibido y cerrado: /edit muestra el cartel con «Editar» y las casas para ver, sin pistola" do
    recibir!
    ingresar(@supervisor)
    get edit_manifiesto_url(@abierto)

    assert_select "[data-candado='cerrado'] form[action=?] button", abrir_edicion_manifiesto_path(@abierto), text: /Editar/
    assert_select "#manifiesto-cajas-vista"
    assert_select "#buscar_paquete", count: 0
    assert_select "[data-controller~='manifiesto-quitar']", count: 0
  end

  # En /edit F8 es «Guardar». Si «Solo Finalizar» (también F8) se pintara
  # arriba, la tecla finalizaría el manifiesto: el primer `data-shortcut` gana.
  test "en /edit la única F8 es Guardar: los botones de finalizar no están" do
    ingresar(@supervisor)
    get edit_manifiesto_url(@abierto)

    assert @abierto.paquetes.any?, "con paquetes la ficha sí ofrece finalizar"
    assert_select "[data-shortcut='F8']", count: 1
    assert_select "button[type='submit'][data-shortcut='F8']", text: /Guardar/
    assert_select "form[action=?]", finalizar_manifiesto_path(@abierto), count: 0
    assert_select "#manifiesto-acciones-arriba", count: 0,
                  message: "el turbo_stream de cada paquete repinta ese bloque con finalizar adentro"
  end

  test "la ficha sigue con sus cierres" do
    ingresar(@supervisor)
    get manifiesto_url(@abierto)

    assert_select "#manifiesto-acciones-arriba form[action=?]", finalizar_manifiesto_path(@abierto)
    assert_contenido_editable
  end

  test "las tres acciones de cada caja van juntas y el basurero no es un bloque rojo" do
    ingresar(@supervisor)
    get edit_manifiesto_url(@abierto)

    assert_select "tr[data-caja=?] td div.inline-flex", @caja.letra do
      assert_select "[aria-label=?]", "Editar la caja #{@caja.letra}"
      assert_select "[aria-label=?]", "Imprimir la etiqueta de la caja #{@caja.letra}"
      assert_select "form.contents button[aria-label=?]", "Eliminar caja #{@caja.letra}"
    end
    assert_select "button[aria-label=?].bg-red-600", "Eliminar caja #{@caja.letra}", count: 0
  end

  # ── Guardar ─────────────────────────────────────────────────────────────

  test "el supervisor guarda guías y fecha de recibido de uno recibido, y queda quién la puso" do
    recibir!
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

  test "un error del formulario vuelve a /edit entero" do
    ingresar(@supervisor)
    patch manifiesto_url(@abierto), params: { manifiesto: { fecha_aduana: Date.tomorrow.iso8601 } }

    assert_response :unprocessable_entity
    assert_match "fecha futura", response.body
    assert_contenido_editable
  end

  test "el digitador no toca uno recibido: ni el encabezado, ni lo de adentro, ni abrirlo" do
    recibir!
    ingresar(@digitador)

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
  end

  # ── Volver a donde estaba ───────────────────────────────────────────────

  test "«Editar» y «Cerrar edición» apretados en /edit vuelven a /edit" do
    recibir!
    ingresar(@supervisor)
    desde_edit = { "Referer" => edit_manifiesto_url(@abierto) }

    patch abrir_edicion_manifiesto_url(@abierto), headers: desde_edit
    assert_redirected_to edit_manifiesto_url(@abierto)
    assert @abierto.reload.edicion_abierta?

    patch cerrar_edicion_manifiesto_url(@abierto), headers: desde_edit
    assert_redirected_to edit_manifiesto_url(@abierto)
  end

  test "una caja agregada desde /edit vuelve a /edit; desde la ficha, a la ficha" do
    ingresar(@supervisor)
    datos = { caja_manifiesto: { tamano_caja_id: tamano_cajas(:mediana).id, peso: 4 } }

    post manifiesto_cajas_url(@abierto), params: datos, headers: { "Referer" => edit_manifiesto_url(@abierto) }
    assert_redirected_to edit_manifiesto_path(@abierto)

    post manifiesto_cajas_url(@abierto), params: datos.merge(print: "true"),
                                         headers: { "Referer" => edit_manifiesto_url(@abierto) }
    assert_redirected_to(/volver=edit/)

    post manifiesto_cajas_url(@abierto), params: datos, headers: { "Referer" => manifiesto_url(@abierto) }
    assert_redirected_to manifiesto_path(@abierto)
  end

  test "la 4×6 abierta con volver=edit devuelve a /edit" do
    ingresar(@supervisor)
    get etiqueta_manifiesto_caja_url(@abierto, @caja, print: true, volver: "edit")

    assert_response :success
    assert_includes response.body, edit_manifiesto_path(@abierto)
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

  def assert_contenido_editable
    assert_select "h2", text: "Casas del manifiesto"
    assert_select "form[action=?]", manifiesto_cajas_path(@abierto)
    assert_select "h2", text: "Agregar paquetes"
    assert_select "#buscar_paquete"
    assert_select "[data-controller~='manifiesto-quitar']"
    assert_select "turbo-frame#manifiesto-paquetes", text: /#{Regexp.escape(@adentro.tracking)}/
  end
end
