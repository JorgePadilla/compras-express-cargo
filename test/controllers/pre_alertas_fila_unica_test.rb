require "test_helper"

# PR-C6.44: una sola fila de paquete.
#
# La fila estaba escrita **seis veces** en la app — cuatro del lado admin
# (servidor + `<template>`, en `new` y en `edit`) y dos en el portal. Y ya
# habían divergido:
#
#   · El aviso de tracking duplicado que pidió Yusef —*"mira, ve, cómo le di
#     enter: ya tiene un error y NO LO DETECTA QUE YA EXISTE"*— llegó a UNA de
#     las cuatro de admin.
#   · El `<template>` de `edit` tenía SEIS celdas contra siete columnas, así
#     que cada fila que agregaba el JS salía corrida: el "—" caía bajo Estado y
#     la papelera bajo Vinculado.
#
# El arreglo no es copiar el aviso a las otras tres: es que el `<template>` se
# **genere del mismo partial** que las filas del servidor. Así la deriva deja
# de ser posible por construcción.
class PreAlertasFilaUnicaTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
    @pa = pre_alertas(:activa)
  end

  # ── Lo que se rompía en silencio ──

  test "la fila que agrega el JS tiene tantas celdas como columnas" do
    # Este test está ROJO contra la implementación vieja: 7 columnas, 6 celdas.
    get edit_pre_alerta_url(@pa)

    columnas = trozo(/<thead.*?<\/thead>/m).scan(/<th\b/).size
    celdas   = plantilla.scan(/<td\b/).size

    assert_equal columnas, celdas,
      "la fila nueva sale corrida: la papelera cae bajo otra columna"
  end

  test "la fila del servidor y la del JS tienen las mismas celdas" do
    get edit_pre_alerta_url(@pa)

    primera_del_servidor = trozo(/<tbody.*?<\/tbody>/m)[/<tr\b.*?<\/tr>/m].to_s

    assert_equal primera_del_servidor.scan(/<td\b/).size, plantilla.scan(/<td\b/).size
  end

  # ── El aviso de Yusef, en las cuatro ──

  test "en new, la plantilla avisa del tracking repetido igual que la fila del servidor" do
    get new_pre_alerta_url

    assert_match(/data-controller="[^"]*\btracking-duplicado\b/, plantilla,
      "al agregar una fila con el boton, el aviso desaparecia")
  end

  test "en edit, las dos filas avisan del tracking repetido" do
    # `edit` no lo tenia en NINGUNA de sus dos copias.
    get edit_pre_alerta_url(@pa)

    assert_match(/data-controller="[^"]*\btracking-duplicado\b/, trozo(/<tbody.*?<\/tbody>/m))
    assert_match(/data-controller="[^"]*\btracking-duplicado\b/, plantilla)
  end

  test "en edit las dos filas traen las defensas contra el autofill" do
    # Yusef: "/pre-alertas/new pero rol Admin -> abre tarjetas de credito en
    # tracking". El arreglo nunca habia llegado a `edit`.
    get edit_pre_alerta_url(@pa)

    [ trozo(/<tbody.*?<\/tbody>/m), plantilla ].each do |donde|
      campo = donde[/<input[^>]*\[tracking\][^>]*>/].to_s
      assert_match(/autocomplete="off"/, campo)
      assert_match(/data-1p-ignore/, campo)
    end
  end

  # ── Las filas nuevas se borran del DOM, no se marcan ──

  test "la plantilla NO trae el campo _destroy" do
    # `removePaquete` bifurca segun exista ese campo: si existe marca la fila y
    # llama a `autosave()`; si no, la saca del DOM. Una fila recien agregada
    # tiene que tomar el segundo camino — con el primero quedaria un <tr>
    # escondido y un PATCH al pedo.
    get edit_pre_alerta_url(@pa)

    assert_no_match(/_destroy/, plantilla)
    assert_match(/_destroy/, trozo(/<tbody.*?<\/tbody>/m), "la fila guardada si lo necesita")
  end

  test "la plantilla se marca como fila nueva" do
    get edit_pre_alerta_url(@pa)

    assert_match(/data-new-record="true"/, plantilla)
  end

  test "la plantilla no trae un id de registro que no existe" do
    get edit_pre_alerta_url(@pa)

    assert_no_match(/name="pre_alerta\[pre_alerta_paquetes_attributes\]\[NEW_INDEX\]\[id\]"/, plantilla)
  end

  # ── El aviso no se avisa a sí mismo ──

  test "check_tracking no avisa sobre el paquete de la propia fila" do
    # Cada PreAlertaPaquete materializa un Paquete en estado pre_alerta. Sin la
    # exclusión, tocar el tracking de una fila guardada encontraba su PROPIO
    # paquete y avisaba "ya está en el sistema" — un aviso que no se puede
    # resolver de ninguna forma.
    pap = con_paquete_materializado
    assert pap.paquete_id.present?, "el callback no materializó el paquete"

    get check_tracking_paquetes_url, params: {
      tracking: pap.tracking, excluir_paquete_id: pap.paquete_id
    }

    assert_equal false, JSON.parse(response.body)["exists"]
  end

  test "sin la exclusion el aviso sigue saliendo" do
    # El otro lado: la pistola de Miami nunca manda el parámetro, así que se
    # comporta exactamente igual que antes.
    pap = con_paquete_materializado

    get check_tracking_paquetes_url, params: { tracking: pap.tracking }

    assert_equal true, JSON.parse(response.body)["exists"]
  end

  test "la fila guardada le pasa su paquete al aviso" do
    pap = con_paquete_materializado

    get edit_pre_alerta_url(@pa)

    assert_match(/data-tracking-duplicado-excluir-paquete-id-value="#{pap.paquete_id}"/,
                 trozo(/<tbody.*?<\/tbody>/m))
  end

  # ── El portal no se movió ──

  test "el portal tambien genera su plantilla del partial" do
    # El portal ya tenía una sola fila en ERB, pero su `<template>` seguía
    # escrito a mano. Ahora sale del mismo partial.
    delete session_url
    cliente = clientes(:juan)
    post session_url, params: { email_address: cliente.email, password: "Cliente123!" }

    get edit_cuenta_pre_alerta_url(pre_alertas(:activa))

    assert_response :success
    assert_match(/NEW_INDEX/, plantilla)
    assert_match(/data-new-record="true"/, plantilla)
    assert_no_match(/_destroy/, plantilla, "una fila nueva se saca del DOM, no se marca")
  end

  private

  # Los fixtures no corren callbacks, así que sus PAPs no tienen el Paquete que
  # `crear_paquete_esperado` materializa. Se crea uno de verdad para reproducir
  # el caso: la fila que consulta por su propio tracking.
  def con_paquete_materializado
    @pa.pre_alerta_paquetes.create!(tracking: "1Z999FILAUNICA", descripcion: "Zapatos").reload
  end

  def plantilla
    trozo(/<template[^>]*>.*?<\/template>/m)
  end

  def trozo(regex)
    response.body[regex].to_s
  end
end
