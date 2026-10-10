require "test_helper"

# C30-06 · El manifiesto finalizado: bloqueado de verdad, y un «Editar» que lo
# abre entero. C30-07 · Las cajas se ven siempre, con lo que llevan adentro.
#
# Yusef, 2026-10-09:
#
#   > "Esto está bloqueado, no puede hacer nada más imprimir… re-imprimir una
#   >  etiqueta, las etiquetas individuales, imprimir manifiesto, imprimir el
#   >  listado, exportar, está bien."
#   > "Lo que no vas a poder hacer es modificar nada, hasta que le dejes editar;
#   >  ahí se abre como que estás haciéndolo, sí podés modificar todo."
#   > "Cuando ya está bloqueado son los supervisores."
#
# Antes de esto el candado cuidaba solo el encabezado: agregar, sacar, cajas y
# empaque no preguntaban nada en el servidor.
class ManifiestoFinalizadoSeCorrigeTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze
  JSON_ = { "Accept" => "application/json" }.freeze

  setup do
    @supervisor = users(:supervisor_miami)
    @digitador = users(:digitador)
    @cer = tipo_envios(:cer)
    @manifiesto = manifiestos(:creado)

    @adentro = paquetes(:empacado)
    @adentro.update_columns(tipo_envio_id: @cer.id)
    @caja = @manifiesto.cajas.create!(tamano_caja: tamano_cajas(:mediana), peso: 10, user: @supervisor)
    @manifiesto.meter!(@adentro, user: @supervisor, caja_manifiesto: @caja)
    assert_not FinalizarManifiesto.new(@manifiesto, user: @supervisor).call.bloqueado?
    @manifiesto.reload

    # El que «se quedó» y se agrega tarde.
    @tarde = paquetes(:recibido)
    @tarde.tareas.update_all(estado: "realizada")
    @tarde.update_columns(tipo_envio_id: @cer.id)
  end

  # ── Cerrado: nada de lo de adentro se toca, ni siquiera el supervisor ──

  test "cerrado, el digitador no agrega, no saca, no escanea ni arma cajas" do
    ingresar(@digitador)
    assert_candado_cerrado
  end

  test "cerrado, el supervisor tampoco: primero tiene que apretar «Editar»" do
    ingresar(@supervisor)
    assert_candado_cerrado
  end

  test "cerrado, el empaque tampoco mete paquetes" do
    ingresar(@supervisor)
    post manifiesto_escanear_empaque_url(@manifiesto, caja_id: @caja.id), params: { codigo: @tarde.tracking }, as: :json

    assert_equal "bloqueado", response.parsed_body["resultado"]
    assert_nil @tarde.reload.manifiesto_id
  end

  test "cerrado, re-imprimir las 4×6 y la hoja sigue andando" do
    ingresar(@digitador)

    get etiqueta_manifiesto_caja_url(@manifiesto, @caja, print: true)
    assert_response :success
    get etiquetas_manifiesto_cajas_url(@manifiesto, print: true)
    assert_response :success
    get documento_manifiesto_url(@manifiesto, print: true)
    assert_response :success
    get listado_manifiesto_url(@manifiesto, print: true)
    assert_response :success
  end

  # ── Abrir y cerrar ──────────────────────────────────────────────────────

  test "el supervisor aprieta «Editar» y queda abierto" do
    ingresar(@supervisor)
    patch abrir_edicion_manifiesto_url(@manifiesto)

    assert_redirected_to manifiesto_url(@manifiesto)
    assert @manifiesto.reload.edicion_abierta?
    assert_equal @supervisor, @manifiesto.edicion_abierta_por
  end

  test "el digitador no lo abre" do
    ingresar(@digitador)
    patch abrir_edicion_manifiesto_url(@manifiesto)

    assert_not @manifiesto.reload.edicion_abierta?
    assert_match(/supervisor/, flash[:alert])
  end

  # PR-C30.14 · Antes: «ya en aduana no se abre, y se dice por qué». Desde la
  # decisión de Jorge del 2026-10-10 (pendiente de confirmar con Yusef), en
  # aduana y recibido también se abren; el que no se abre es el interno.
  test "en aduana también se abre; el interno no, y se dice por qué" do
    @manifiesto.update!(estado: "en_aduana")
    ingresar(@supervisor)
    patch abrir_edicion_manifiesto_url(@manifiesto)
    assert @manifiesto.reload.edicion_abierta?

    @manifiesto.cerrar_edicion!
    @manifiesto.update_columns(tipo: "interno")
    patch abrir_edicion_manifiesto_url(@manifiesto)
    assert_not @manifiesto.reload.edicion_abierta?
    assert_match(/solo se reabren los manifiestos oficiales/, flash[:alert])
  end

  test "«Cerrar edición» lo bloquea otra vez; el digitador no puede cerrarlo" do
    @manifiesto.abrir_edicion!(@supervisor)

    ingresar(@digitador)
    patch cerrar_edicion_manifiesto_url(@manifiesto)
    assert @manifiesto.reload.edicion_abierta?

    ingresar(@supervisor)
    patch cerrar_edicion_manifiesto_url(@manifiesto)
    assert_not @manifiesto.reload.edicion_abierta?
  end

  # ── Abierto: se corrige todo ────────────────────────────────────────────

  test "abierto, el supervisor agrega uno que se quedó y sale a enviado" do
    @manifiesto.abrir_edicion!(@supervisor)
    ingresar(@supervisor)

    post add_paquete_manifiesto_url(@manifiesto), params: { paquete_id: @tarde.id }, headers: TURBO

    assert_response :success
    @tarde.reload
    assert_equal @manifiesto.id, @tarde.manifiesto_id
    assert_equal "enviado_honduras", @tarde.estado
    assert_equal @supervisor.id, @tarde.fecha_enviado_by_user_id
  end

  test "abierto, el que tiene tarea pendiente no entra y se dice" do
    paquetes(:recibido).tareas.update_all(estado: "pendiente")
    @manifiesto.abrir_edicion!(@supervisor)
    ingresar(@supervisor)

    post add_paquete_manifiesto_url(@manifiesto), params: { paquete_id: @tarde.id }, headers: TURBO

    assert_includes response.body, "tareas pendientes"
    assert_nil @tarde.reload.manifiesto_id
  end

  test "abierto, el supervisor saca el que no se fue y vuelve a la bodega" do
    @manifiesto.abrir_edicion!(@supervisor)
    ingresar(@supervisor)

    delete remove_paquete_manifiesto_url(@manifiesto, paquete_id: @adentro.id), headers: TURBO

    assert_response :success
    @adentro.reload
    assert_nil @adentro.manifiesto_id
    assert_equal "recibido_miami", @adentro.estado
    assert_nil @adentro.fecha_enviado
    assert_nil @adentro.caja_manifiesto_id
  end

  test "abierto, el supervisor arma y corrige cajas" do
    @manifiesto.abrir_edicion!(@supervisor)
    ingresar(@supervisor)

    assert_difference -> { @manifiesto.cajas.count }, 1 do
      post manifiesto_cajas_url(@manifiesto), params: { caja_manifiesto: { tamano_caja_id: tamano_cajas(:mediana).id, peso: 4 } }
    end
    patch manifiesto_caja_url(@manifiesto, @caja), params: { caja_manifiesto: { peso: 48 } }
    assert_equal 48, @caja.reload.peso.to_i
  end

  test "abierto por el supervisor, el digitador sigue sin poder" do
    @manifiesto.abrir_edicion!(@supervisor)
    ingresar(@digitador)
    assert_candado_cerrado(abierto: true)
  end

  # ── Eliminar escaneando ────────────────────────────────────────────────

  test "la pistola de «Eliminar paquetes» encuentra el que está acá" do
    @manifiesto.abrir_edicion!(@supervisor)
    ingresar(@supervisor)

    post escanear_para_quitar_manifiesto_url(@manifiesto), params: { codigo: @adentro.tracking }, as: :json

    assert_equal "ok", response.parsed_body["resultado"]
    assert_equal @adentro.id, response.parsed_body["paquete_id"]
    assert @adentro.reload.manifiesto_id, "solo clasifica: el que saca es remove_paquete"
  end

  test "uno que no está en este manifiesto se dice, y no se toca" do
    @manifiesto.abrir_edicion!(@supervisor)
    ingresar(@supervisor)

    post escanear_para_quitar_manifiesto_url(@manifiesto), params: { codigo: @tarde.tracking }, as: :json

    assert_equal "no_esta_aca", response.parsed_body["resultado"]
    assert_match(/no está en este manifiesto/, response.parsed_body["mensaje"])
  end

  test "uno que no existe" do
    @manifiesto.abrir_edicion!(@supervisor)
    ingresar(@supervisor)

    post escanear_para_quitar_manifiesto_url(@manifiesto), params: { codigo: "NOEXISTE999" }, as: :json
    assert_equal "no_encontrado", response.parsed_body["resultado"]
  end

  # ── La pantalla ─────────────────────────────────────────────────────────

  test "cerrado: se ven las cajas con sus paquetes y la impresora, sin lápiz ni basurero" do
    ingresar(@digitador)
    get manifiesto_url(@manifiesto)

    assert_select "#manifiesto-cajas-vista" do
      assert_select "a", text: /Imprimir las 4×6/
      assert_select "a[aria-label=?]", "Imprimir la etiqueta de la caja #{@caja.letra}"
      assert_select "[aria-label=?]", "Editar la caja #{@caja.letra}", count: 0
      assert_select "[aria-label=?]", "Eliminar caja #{@caja.letra}", count: 0
      assert_select "td", text: /#{Regexp.escape(@adentro.tracking)}|1 paquete/
    end
    assert_select "#buscar_paquete", count: 0
    assert_select "[data-controller~='manifiesto-quitar']", count: 0
  end

  test "cerrado: el «Editar» del encabezado se esconde; la puerta es la del cartel" do
    ingresar(@supervisor)
    get manifiesto_url(@manifiesto)

    assert_select "a[href=?]", edit_manifiesto_path(@manifiesto), count: 0
    assert_select "form[action=?] button", abrir_edicion_manifiesto_path(@manifiesto), text: /Editar/
  end

  test "abierto: cartel con quién lo abrió, «Cerrar edición», cajas, pistola y «Eliminar paquetes»" do
    @manifiesto.abrir_edicion!(@supervisor)
    ingresar(@supervisor)
    get manifiesto_url(@manifiesto)

    assert_select "[data-candado='abierto']", text: /#{@supervisor.nombre}/
    assert_select "form[action=?] button", cerrar_edicion_manifiesto_path(@manifiesto), text: /Cerrar edición/
    assert_select "#buscar_paquete"
    assert_select "[data-controller~='manifiesto-quitar']"
    assert_select "[aria-label=?]", "Editar la caja #{@caja.letra}"
    assert_select "a[href=?]", edit_manifiesto_path(@manifiesto)
  end

  test "C30-07 · también abierto, cada caja dice qué lleva" do
    abierto = manifiestos(:enviado)
    abierto.update_columns(estado: "creado")
    caja = abierto.cajas.create!(tamano_caja: tamano_cajas(:mediana), peso: 5, user: @supervisor)
    @tarde.update_columns(manifiesto_id: abierto.id, caja_manifiesto_id: caja.id)

    ingresar(@digitador)
    get manifiesto_url(abierto)

    assert_select "th", text: "Paquetes adentro"
    assert_select "tr[data-caja=?] td", caja.letra, text: /RMI0002026000902/
  end

  # Una pestaña vieja actuando sobre uno que se acaba de cerrar: la respuesta
  # refresca la página —sin `request-id`, o Turbo la ignora por venir del
  # mismo pedido— y el aviso viaja en el flash de esa visita.
  test "el 403 por turbo_stream refresca la página y el aviso llega en el flash" do
    ingresar(@supervisor)

    delete remove_paquete_manifiesto_url(@manifiesto, paquete_id: @adentro.id),
           headers: TURBO.merge("X-Turbo-Request-Id" => "pestana-vieja")

    assert_response :forbidden
    assert_match %r{<turbo-stream action="refresh"}, response.body
    assert_no_match(/request-id/, response.body, "con el id del pedido Turbo no refresca")
    assert_no_match(/action="prepend"/, response.body)

    get manifiesto_url(@manifiesto)
    assert_match "aprieta «Editar»", response.body
  end

  private

  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def assert_candado_cerrado(abierto: false)
    post add_paquete_manifiesto_url(@manifiesto), params: { paquete_id: @tarde.id }, headers: TURBO
    assert_response :forbidden
    assert_nil @tarde.reload.manifiesto_id

    post escanear_manifiesto_url(@manifiesto), params: { codigo: @tarde.tracking }, as: :json
    assert_equal "bloqueado", response.parsed_body["resultado"]
    esperado = abierto ? /solo un supervisor/ : /aprieta «Editar»/
    assert_match esperado, response.parsed_body["mensaje"]

    delete remove_paquete_manifiesto_url(@manifiesto, paquete_id: @adentro.id), headers: TURBO
    assert_response :forbidden
    assert_equal @manifiesto.id, @adentro.reload.manifiesto_id
    assert_equal "enviado_honduras", @adentro.estado

    post escanear_para_quitar_manifiesto_url(@manifiesto), params: { codigo: @adentro.tracking }, as: :json
    assert_equal "bloqueado", response.parsed_body["resultado"]

    assert_no_difference -> { @manifiesto.cajas.count } do
      post manifiesto_cajas_url(@manifiesto), params: { caja_manifiesto: { tamano_caja_id: tamano_cajas(:mediana).id, peso: 4 } }
    end
    assert_redirected_to manifiesto_url(@manifiesto)

    delete manifiesto_caja_url(@manifiesto, @caja)
    assert @caja.reload.persisted?
  end
end
