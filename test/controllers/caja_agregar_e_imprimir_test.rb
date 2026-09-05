require "test_helper"

# C23-05 · «Agregar e imprimir», el segundo botón de las casas.
#
#   > "Acá un detalle que sería bueno, que **después de que le damos a agregar,
#   >  de un solo** te… te las imprimo."
#   > **Jorge:** "¿Querés que la tire de un solo?" · **Yusef:** "Sí, que **le
#   >  tire la que está haciendo** de un solo."
#
# Es la misma pareja de botones que tiene la pantalla vieja que su equipo usa
# todos los días —*«Solo Agregar (F5)»* y *«Agregar/Imprimir (F9)»*—, ya anotada
# en el encabezado de `CajasManifiestoController` desde `C21-04`.
#
# **Lo que este test protege de verdad es que no vuelva por popup.** Esta
# impresión nace de un POST, no de un clic, y Chrome bloquea el `window.open`
# que no nace de un gesto — el tropiezo que ya costó en `/entrega_personal`. Y
# no se puede probar en un system test: el Chrome de los tests corre con
# `--disable-popup-blocking`, así que un `window.open` daría verde con el bug
# puesto. Lo que sí se puede afirmar es la forma que lo evita: **un redirect**.
class CajaAgregarEImprimirTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }
    @manifiesto = manifiestos(:creado)
  end

  test "agregar sin pedir impresión vuelve al manifiesto, como siempre" do
    assert_difference -> { @manifiesto.cajas.count }, 1 do
      post manifiesto_cajas_path(@manifiesto),
           params: { caja_manifiesto: { alto: 23, largo: 23, ancho: 36, peso: 131 } }
    end

    assert_redirected_to manifiesto_path(@manifiesto)
  end

  test "agregar e imprimir manda a la 4×6 de la caja recién creada" do
    assert_difference -> { @manifiesto.cajas.count }, 1 do
      post manifiesto_cajas_path(@manifiesto),
           params: { print: "true",
                     caja_manifiesto: { alto: 23, largo: 23, ancho: 36, peso: 131 } }
    end

    caja = @manifiesto.cajas.order(:id).last
    assert_redirected_to etiqueta_manifiesto_caja_path(@manifiesto, caja, print: true, volver: 1)
  end

  # La etiqueta se lleva la pestaña que ya estaba abierta, así que tiene que
  # saber devolverla. Sin esto el operario queda mirando una 4×6 impresa sin
  # forma de volver más que el Atrás del navegador.
  test "la etiqueta abierta así sabe volver al manifiesto" do
    caja = @manifiesto.cajas.create!(alto: 23, largo: 23, ancho: 36, peso: 131)

    get etiqueta_manifiesto_caja_path(@manifiesto, caja, print: true, volver: 1)

    assert_response :success
    assert_includes response.body, manifiesto_path(@manifiesto).to_json
  end

  # Y sin `volver=1` sigue cerrándose sola, que es como la abren las otras dos
  # puertas (el botón de la fila y «Imprimir las 4×6»).
  test "sin volver=1 la etiqueta se cierra, no navega" do
    caja = @manifiesto.cajas.create!(alto: 23, largo: 23, ancho: 36, peso: 131)

    get etiqueta_manifiesto_caja_path(@manifiesto, caja, print: true)

    assert_includes response.body, "var despues = \"\""
  end

  # `volver` no acepta una URL: si aceptara, sería un redirect abierto servido
  # desde una pantalla que cualquier operario puede abrir.
  test "volver no es una URL que se pueda dictar" do
    caja = @manifiesto.cajas.create!(alto: 23, largo: 23, ancho: 36, peso: 131)

    get etiqueta_manifiesto_caja_path(@manifiesto, caja, print: true, volver: "https://evil.example.com")

    assert_includes response.body, "var despues = \"\""
  end

  # La pantalla vieja usa F9 para «Agregar/Imprimir», y acá **no se puede**:
  # F9 ya es «Finalizar e Imprimir», que cierra el manifiesto entero.
  # `keyboard_shortcuts_controller` resuelve con `document.querySelector` —el
  # primero del DOM—, así que dos botones con la misma tecla no se reparten
  # nada: gana el de arriba y el otro queda con un rótulo que miente.
  #
  # El test es más ancho que el botón a propósito: cualquier tecla repetida en
  # esta ficha tiene que ser **la misma acción** (la barra de arriba y la de
  # abajo repiten Finalizar, y eso está bien).
  test "ninguna tecla de esta ficha apunta a dos acciones distintas" do
    # Con la ficha **completa**: «Finalizar e Imprimir» —el otro que se querría
    # llamar F9— pide `paquetes.any?` y `cajas.any?`, y sin las dos cosas la
    # ficha no lo pinta y este test no vería nada. Es el error que tuvo antes:
    # pasaba en verde con las dos teclas puestas.
    @manifiesto.cajas.create!(alto: 23, largo: 23, ancho: 36, peso: 131)
    paquetes(:disponible_entrega_juan)
      .update!(manifiesto: @manifiesto, tipo_envio: @manifiesto.tipo_envios.first)

    get manifiesto_path(@manifiesto)

    # C23-13: «Finalizar e Imprimir» se quedó **sin tecla** —F8 es Excel en toda
    # la app y era la única que significaba dos cosas—. La precondición ahora es
    # «Solo Finalizar» (F10), que es el otro botón del bloque: sin él en la
    # página este test no prueba nada.
    assert_select "[data-shortcut='F10']", { minimum: 1 },
                  "sin los botones de finalizar en la página este test no prueba nada"

    por_tecla = Hash.new { |h, k| h[k] = [] }
    css_select("[data-shortcut]").each do |el|
      por_tecla[el["data-shortcut"]] << el.text.squish
    end

    por_tecla.each do |tecla, etiquetas|
      assert_equal 1, etiquetas.uniq.size,
                   "#{tecla} está en dos acciones distintas — #{etiquetas.uniq.join(' / ')}. " \
                   "Gana la primera del DOM y la otra promete algo que no hace."
    end
  end

  test "si la caja no se puede guardar, no manda a imprimir nada" do
    assert_no_difference -> { @manifiesto.cajas.count } do
      post manifiesto_cajas_path(@manifiesto),
           params: { print: "true", caja_manifiesto: { peso: -5 } }
    end

    assert_redirected_to manifiesto_path(@manifiesto)
  end

  # ── C23-12 · Las teclas ──────────────────────────────────────────────────

  # Los dos botones del formulario muestran su tecla pero **no** emiten
  # `data-shortcut`: las escucha `caja_manifiesto_controller`. Si además las
  # registraran, el controller global les haría click encima y se guardarían
  # **dos cajas** — el doble disparo que ya pasó en `/entrega_personal`.
  test "los botones del formulario muestran la tecla pero no la registran" do
    get manifiesto_path(@manifiesto)

    assert_match(/Agregar caja\s*\(F5\)/, response.body.gsub(/<[^>]+>/, " "))
    assert_match(/Agregar e imprimir\s*\(F9\)/, response.body.gsub(/<[^>]+>/, " "))
    assert_select "[data-shortcut='F5']", 0, "F5 la escucha el formulario, no el controller global"
    assert_select "[data-shortcut='F9']", 0, "F9 la escucha el formulario, no el controller global"
  end

  # Y el formulario tiene que poder encontrarlos para disparar el submit.
  test "el formulario alcanza a sus dos botones por target" do
    get manifiesto_path(@manifiesto)

    assert_select "[data-caja-manifiesto-target='agregar']", 1
    assert_select "[data-caja-manifiesto-target='agregarEImprimir']", 1
  end

  # F9 se la lleva «Agregar e imprimir», que es la del sistema viejo y la que
  # pasa decenas de veces por manifiesto.
  #
  # «Finalizar e Imprimir» pasó cuatro días en **F8** y estuvo mal: F8 es Excel
  # en todas las demás pantallas, y era la única tecla del sistema que
  # significaba dos cosas distintas. Ahora va **sin tecla**: finalizar pasa una
  # vez por manifiesto, y la pantalla vieja tampoco le da tecla.
  test "«Finalizar e Imprimir» no le roba la tecla a nadie" do
    @manifiesto.cajas.create!(alto: 23, largo: 23, ancho: 36, peso: 131)
    paquetes(:disponible_entrega_juan)
      .update!(manifiesto: @manifiesto, tipo_envio: @manifiesto.tipo_envios.first)

    get manifiesto_path(@manifiesto)

    assert_select "[data-shortcut='F9']", 0, "F9 quedó para el formulario de casas"
    assert_select "[data-shortcut='F8']", 0, "F8 es Excel en toda la app"
    assert_select "[data-shortcut='F11']", 0, "no se pudo comprobar que F11 llegue a la página"
  end

  # ── C21-04 · Que el No. Doc se pueda escribir ─────────────────────────────

  test "el formulario tiene dónde teclear el No. Doc" do
    get manifiesto_path(@manifiesto)

    assert_select "input[name='caja_manifiesto[numero_doc]']", 1,
                  "la 4×6 lo imprime y caja_params lo permite: sin campo no se puede llenar nunca"
  end

  test "el No. Doc se guarda al agregar la caja" do
    post manifiesto_cajas_path(@manifiesto),
         params: { caja_manifiesto: { alto: 23, largo: 23, ancho: 36, peso: 131, numero_doc: "DM7155" } }

    assert_equal "DM7155", @manifiesto.cajas.order(:id).last.numero_doc
  end

  test "la tabla de casas muestra el No. Doc" do
    @manifiesto.cajas.create!(alto: 23, largo: 23, ancho: 36, peso: 131, numero_doc: "DM7155")

    get manifiesto_path(@manifiesto)

    assert_select "th", text: "No. Doc"
    assert_select "td", text: "DM7155"
  end
end
