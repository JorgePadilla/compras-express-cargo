require "test_helper"

class ManifiestosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @digitador = users(:digitador)
    post session_url, params: { email_address: @digitador.email_address, password: "password123" }
    @manifiesto = manifiestos(:creado)
  end

  test "should get index" do
    get manifiestos_url
    assert_response :success
  end

  test "should search manifiestos" do
    get manifiestos_url, params: { q: "MA-000001" }
    assert_response :success
  end

  test "should get new" do
    get new_manifiesto_url
    assert_response :success
  end

  test "should create manifiesto" do
    assert_difference("Manifiesto.count") do
      post manifiestos_url, params: { manifiesto: {
        tipo_envio_ids: [ tipo_envios(:cer).id ]
      } }
    end
    assert_redirected_to manifiesto_url(Manifiesto.last)
  end

  # ── C21-02 · La numeración anual, que llevaba meses muerta ───────────────
  #
  # `RP-46`: `Manifiesto#generate_numero` siempre supo numerar
  # `MM2026000001` cuando hay sucursal de origen — pero **ningún controller la
  # asignaba**, así que el fallback legacy `MA-…` se comía todos los casos y
  # nadie se enteraba, porque los tests del modelo crean el manifiesto pelado y
  # el fallback les daba la razón. La brecha era que **nada probaba el camino de
  # la pantalla**.
  #
  # Y el año no es un capricho nuestro. Yusef: *"para poder limpiar el año,
  # poder ordenar cosas, saber de qué año es"*, y lo comparó con lo que ya
  # tenemos: *"ese número va a ir igual que el recibo de warehouse; esto es
  # relativamente un warehouse, solo que es un manifiesto"*.
  test "el manifiesto que crea la pantalla nace con el número del año" do
    post manifiestos_url, params: { manifiesto: { tipo_envio_ids: [ tipo_envios(:cer).id ] } }

    assert_match(/\AM[A-Z]#{Time.zone.now.year}\d{6}\z/, Manifiesto.last.numero,
                 "sin sucursal de origen el número vuelve a caer al formato viejo")
    assert Manifiesto.last.sucursal_origen.present?
  end

  test "la sucursal de origen se puede elegir, y manda sobre la de la sesión" do
    otra = sucursales(:miami)

    post manifiestos_url, params: { manifiesto: {
      tipo_envio_ids: [ tipo_envios(:cer).id ], sucursal_origen_id: otra.id
    } }

    assert_equal otra, Manifiesto.last.sucursal_origen
  end

  # ── C21-03 · Los tipos de envío NUESTROS ────────────────────────────────
  #
  # *"Aquí es selección múltiple… podés seleccionar todos los cinco tipos de
  # servicio que tengo actuales. ¿Por qué seleccionás todo? Porque a veces
  # combinás todo y lo mandás."* Y la regla: *"no puede ser sin ninguno, tiene
  # que llevar uno mínimo"*.
  test "se pueden mandar varios tipos de envío nuestros" do
    post manifiestos_url, params: { manifiesto: {
      tipo_envio_ids: [ tipo_envios(:cer).id, tipo_envios(:cem).id ]
    } }

    assert_equal 2, Manifiesto.last.tipo_envios.count
  end

  test "sin ningún tipo de envío nuestro no se crea" do
    assert_no_difference("Manifiesto.count") do
      post manifiestos_url, params: { manifiesto: { expedido_por: "Julien" } }
    end

    assert_response :unprocessable_entity
  end

  # ── C21-11 · Las guías del proveedor, que son varias ────────────────────
  #
  # *"El número de guía termina siendo varios"* — `286441-1`, `-2`, `-3`: *"es
  # el mismo número, solo tiene el 1, el 2 y el 3. Es el mismo que nosotros, la
  # misma teoría"*. Y no son obligatorias al crear: las llena después San Pedro
  # Sula.
  test "un manifiesto lleva varias guías del proveedor" do
    post manifiestos_url, params: { manifiesto: {
      tipo_envio_ids: [ tipo_envios(:cer).id ],
      guias_attributes: {
        "0" => { numero: "286441-1" }, "1" => { numero: "286441-2" }, "2" => { numero: "" }
      }
    } }

    manifiesto = Manifiesto.last
    assert_equal %w[286441-1 286441-2], manifiesto.numeros_de_guia,
                 "el renglón vacío no puede convertirse en una guía en blanco"
  end

  test "la búsqueda encuentra el manifiesto por la guía del proveedor" do
    @manifiesto.guias.create!(numero: "286441-3")

    get manifiestos_url, params: { q: "286441-3" }

    assert_response :success
    assert_select "td", text: /#{@manifiesto.numero}/
  end

  test "should show manifiesto" do
    get manifiesto_url(@manifiesto)
    assert_response :success
  end

  test "should get edit" do
    get edit_manifiesto_url(@manifiesto)
    assert_response :success
  end

  test "should update manifiesto" do
    patch manifiesto_url(@manifiesto), params: { manifiesto: { expedido_por: "Julien" } }
    assert_redirected_to manifiesto_url(@manifiesto)
  end

  test "should add paquete to manifiesto" do
    paquete = paquetes(:empacado)
    post add_paquete_manifiesto_url(@manifiesto), params: { paquete_id: paquete.id }
    assert_redirected_to manifiesto_url(@manifiesto)
    paquete.reload
    assert_equal @manifiesto, paquete.manifiesto
    assert_equal "empacado", paquete.estado
  end

  test "should remove paquete from manifiesto" do
    paquete = paquetes(:empacado)
    paquete.update!(manifiesto: @manifiesto)

    delete remove_paquete_manifiesto_url(@manifiesto, paquete_id: paquete.id)
    assert_redirected_to manifiesto_url(@manifiesto)
    paquete.reload
    assert_nil paquete.manifiesto_id
    # PR-C6.22: vuelve a recibido. Con el módulo de empaque sin existir,
    # `empacado` no lo asigna ninguna pantalla — devolver ahí dejaba el
    # paquete en un estado del que nadie es dueño.
    assert_equal "recibido_miami", paquete.estado
  end

  test "should enviar manifiesto" do
    paquete = paquetes(:empacado)
    paquete.update!(manifiesto: @manifiesto)
    @manifiesto.recalculate_totals!

    patch enviar_manifiesto_url(@manifiesto)
    assert_redirected_to manifiesto_url(@manifiesto)
    @manifiesto.reload
    assert_equal "enviado", @manifiesto.estado
  end

  test "add_paquete responds with turbo_stream" do
    paquete = paquetes(:empacado)
    post add_paquete_manifiesto_url(@manifiesto), params: { paquete_id: paquete.id }, as: :turbo_stream
    assert_response :success
    paquete.reload
    assert_equal @manifiesto, paquete.manifiesto
  end

  test "remove_paquete responds with turbo_stream" do
    paquete = paquetes(:empacado)
    paquete.update!(manifiesto: @manifiesto)

    delete remove_paquete_manifiesto_url(@manifiesto, paquete_id: paquete.id), as: :turbo_stream
    assert_response :success
    paquete.reload
    assert_nil paquete.manifiesto_id
  end

  test "cajero cannot access manifiestos" do
    delete session_url
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }
    get manifiestos_url
    assert_redirected_to root_path
  end
end
