require "test_helper"

# C21-02 · La pantalla de San Pedro.
#
# Yusef: *"es editable… pero no obligatorio… lo ingresan después… le ingresa la
# encargada de operaciones en San Pedro Sula"*, y sobre la fecha: *"es por la
# fecha de recibido en aduana en Honduras, o sea en aduana que es que nosotros
# lo recibimos"*.
#
# El porqué de que sea pantalla y no sección: mientras los dos lados compartían
# el formulario del manifiesto, el recorte por rol era del controller y la vista
# no se enteraba — San Pedro veía los campos de Miami habilitados, los editaba,
# y el sistema le descartaba el cambio **contestándole que se guardó**.
class GuiasAduanaTest < ActionDispatch::IntegrationTest
  setup do
    @manifiesto = manifiestos(:enviado)
    @manifiesto.update_columns(fecha_aduana: nil)
  end

  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  # ── Quién entra ──────────────────────────────────────────────────────────

  test "los jefes de Honduras entran" do
    ingresar(users(:supervisor_prefactura))
    get guias_aduana_index_url
    assert_response :success
  end

  test "Miami no entra: lo suyo es el manifiesto" do
    ingresar(users(:digitador))
    get guias_aduana_index_url
    assert_redirected_to root_path
  end

  test "el cajero tampoco" do
    ingresar(users(:cajero))
    get guias_aduana_index_url
    assert_redirected_to root_path
  end

  # ── La bandeja ───────────────────────────────────────────────────────────

  # *"Solo le aparece lo que tiene que meter."*
  test "lista lo que salió de Miami y todavía le falta algo" do
    ingresar(users(:supervisor_prefactura))
    get guias_aduana_index_url

    assert_select "td", text: /#{@manifiesto.numero}/
    assert_not_includes response.body, manifiestos(:creado).numero,
                        "un manifiesto que todavía no salió no es de esta pantalla"
  end

  test "lo completo se cae de la bandeja" do
    @manifiesto.update_columns(fecha_aduana: Time.current)
    @manifiesto.guias.create!(numero: "286441-1")

    ingresar(users(:supervisor_prefactura))
    get guias_aduana_index_url

    assert_no_match(/#{@manifiesto.numero}/, response.body)
  end

  test "con ?todos=1 se ve también lo ya completo, para corregir" do
    @manifiesto.update_columns(fecha_aduana: Time.current)
    @manifiesto.guias.create!(numero: "286441-1")

    ingresar(users(:supervisor_prefactura))
    get guias_aduana_index_url(todos: 1)

    assert_select "td", text: /#{@manifiesto.numero}/
  end

  # ── Los dos campos ───────────────────────────────────────────────────────

  test "guarda la fecha de recibido en Honduras" do
    ingresar(users(:supervisor_prefactura))

    patch guias_aduana_url(@manifiesto), params: { manifiesto: { fecha_aduana: "2026-08-30" } }

    assert_equal Date.new(2026, 8, 30), @manifiesto.reload.fecha_aduana.to_date
  end

  # C21-11 · *"El número de guía termina siendo varios."*
  test "guarda varias guías del proveedor, y el renglón vacío no cuenta" do
    ingresar(users(:supervisor_prefactura))

    patch guias_aduana_url(@manifiesto), params: { manifiesto: {
      guias_attributes: {
        "0" => { numero: "286441-1" }, "1" => { numero: "286441-2" }, "2" => { numero: "" }
      }
    } }

    assert_equal %w[286441-1 286441-2], @manifiesto.reload.numeros_de_guia
  end

  test "se puede quitar una guía" do
    guia = @manifiesto.guias.create!(numero: "286441-9")
    ingresar(users(:supervisor_prefactura))

    patch guias_aduana_url(@manifiesto), params: { manifiesto: {
      guias_attributes: { "0" => { id: guia.id, numero: guia.numero, _destroy: "1" } }
    } }

    assert_empty @manifiesto.reload.numeros_de_guia
  end

  # ── Lo que esta pantalla NO deja hacer ───────────────────────────────────

  # El corazón del cambio: acá no hay campos de Miami que descartar.
  test "no acepta campos de Miami aunque se los manden" do
    consignatario = Consignatario.create!(nombre: "KARSAM PRUEBA", activo: true)
    ingresar(users(:supervisor_prefactura))

    patch guias_aduana_url(@manifiesto), params: { manifiesto: {
      fecha_aduana: "2026-08-30",
      consignatario_id: consignatario.id, es_prioridad: true, expedido_por: "alguien"
    } }

    @manifiesto.reload
    assert_equal Date.new(2026, 8, 30), @manifiesto.fecha_aduana.to_date, "lo suyo sí entró"
    assert_nil @manifiesto.consignatario_id
    assert_not @manifiesto.es_prioridad?
    assert_nil @manifiesto.expedido_por
  end

  # El manifiesto está finalizado y bloqueado, y aun así esto se llena: es
  # exactamente para lo que existe `CAMPOS_DE_SAN_PEDRO`.
  test "funciona sobre un manifiesto bloqueado" do
    assert @manifiesto.bloqueado?
    ingresar(users(:supervisor_prefactura))

    patch guias_aduana_url(@manifiesto), params: { manifiesto: { fecha_aduana: "2026-08-30" } }

    assert_equal Date.new(2026, 8, 30), @manifiesto.reload.fecha_aduana.to_date
  end

  # ── El `<template>` de la fila nueva ─────────────────────────────────────
  #
  # `PR-C6.44` se pagó caro: la fila de pre-alerta estaba escrita seis veces y
  # el `<template>` a mano tenía SEIS celdas contra siete columnas, así que cada
  # fila que agregaba el JS salía corrida. El arreglo no fue copiar mejor: fue
  # que el template **se genere del mismo partial**. Estos tests cuidan eso.
  #
  # Ojo con el regex: `fields_for` renderiza `name` e `id` **al final** del tag,
  # así que un corte que asuma `name` primero pasa vacío y el test deja de
  # verificar en silencio (`pre_alertas_admin_form_test.rb:28-41`). Se corta el
  # tag entero.
  test "el template sale del mismo partial que las filas" do
    @manifiesto.guias.create!(numero: "286441-1")
    ingresar(users(:supervisor_prefactura))
    get edit_guias_aduana_url(@manifiesto)

    assert_match(/NEW_INDEX/, plantilla, "el template tiene que traer el marcador")
    assert_match(/class="guia-fila/, plantilla, "y la misma clase que la fila real")
    assert_match(/guias-repetidor#quitar/, plantilla, "con su botón de quitar")
  end

  # El `[id]` del template va **presente y vacío**, no ausente. Dos razones:
  # Rails trata un `id` en blanco como registro nuevo (no sale a buscarlo), y el
  # Stimulus lo usa para decidir si al quitar hay que marcar `_destroy` —fila ya
  # guardada— o sacar el nodo del DOM —fila nueva—. Sin el campo, una fila nueva
  # y una vieja se ven iguales.
  test "el template trae el id vacío, que es como el JS distingue fila nueva" do
    ingresar(users(:supervisor_prefactura))
    get edit_guias_aduana_url(@manifiesto)

    campo_id = plantilla[/<input[^>]*NEW_INDEX\]\[id\][^>]*>/].to_s
    assert campo_id.present?, "el campo id tiene que estar"
    assert_no_match(/\bvalue="[^"]+"/, campo_id, "y tiene que salir sin valor")
  end

  test "hay botón de agregar, y ya no tres renglones vacíos fijos" do
    ingresar(users(:supervisor_prefactura))
    get edit_guias_aduana_url(@manifiesto)

    assert_select "button", text: /Agregar guía/
    assert_no_match(/guias_attributes\]\[nueva[0-9]/, response.body,
                    "los tres renglones fijos se fueron")
  end

  # Sin ninguna guía, una fila lista para escribir: entrar y tener que apretar
  # «Agregar» antes de poder teclear es un paso de más en la pantalla que existe
  # justamente para teclear guías.
  test "sin guías arranca con una fila vacía" do
    assert_empty @manifiesto.guias
    ingresar(users(:supervisor_prefactura))
    get edit_guias_aduana_url(@manifiesto)

    assert_equal 1, cuerpo_del_form.scan(/class="guia-fila/).size
  end

  test "con guías cargadas no agrega una vacía de más" do
    @manifiesto.guias.create!(numero: "286441-1")
    ingresar(users(:supervisor_prefactura))
    get edit_guias_aduana_url(@manifiesto)

    assert_equal 1, cuerpo_del_form.scan(/class="guia-fila/).size
  end

  test "la pantalla de edición no muestra los campos de Miami" do
    ingresar(users(:supervisor_prefactura))
    get edit_guias_aduana_url(@manifiesto)

    assert_response :success
    assert_select "select[name='manifiesto[consignatario_id]']", 0
    assert_select "input[name='manifiesto[es_prioridad]']", 0
    assert_select "input[name='manifiesto[fecha_aduana]']"
  end

  private

  def plantilla
    response.body[/<template[^>]*>.*?<\/template>/m].to_s
  end

  # El form **sin** el `<template>`: si no, la fila de adentro del template
  # cuenta como una fila más y los conteos salen de a dos.
  def cuerpo_del_form
    response.body.sub(/<template[^>]*>.*?<\/template>/m, "")
  end
end
