require "test_helper"

# C21-09 · El documento impreso. Yusef anotó dos copias del impreso del legacy
# a mano y de ahí salieron cuatro correcciones. Este test las afirma una por
# una, porque el documento **no existía**: es un papel nuevo, no un arreglo.
class ManifiestoDocumentoTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @manifiesto = manifiestos(:creado)
    @empresa = EmpresaManifiesto.create!(nombre: "PRONTO CARGO TEST",
                                         telefono: "504-2555-1234",
                                         encargado: "Vanessa Discua",
                                         direccion: "Bulevar del Norte, SPS")
    @manifiesto.update!(empresa_manifiesto: @empresa)
  end

  test "el documento sale" do
    get documento_manifiesto_url(@manifiesto)
    assert_response :success
  end

  # Corrección 1: decía «Compras Express Miami».
  test "el encabezado dice Compras Express Logistics LLC y lleva el teléfono" do
    get documento_manifiesto_url(@manifiesto)
    assert_match(/COMPRAS EXPRESS LOGISTICS LLC/i, response.body)
    assert_match(/305-848-0990/, response.body)
    assert_no_match(/Compras Express Miami/i, response.body)
  end

  # Corrección 2: el número lleva el año. La numeración anual la despertó PR-M2.
  test "imprime el número del manifiesto" do
    get documento_manifiesto_url(@manifiesto)
    assert_match(/#{@manifiesto.numero}/, response.body)
  end

  # Corrección 3: faltaban `# tel` y `persona encargada` del transportista.
  test "el bloque del transportista lleva teléfono y encargado" do
    get documento_manifiesto_url(@manifiesto)
    assert_match(/PRONTO CARGO TEST/, response.body)
    assert_match(/# tel/, response.body)
    assert_match(/504-2555-1234/, response.body)
    assert_match(/Persona encargada/, response.body)
    assert_match(/Vanessa Discua/, response.body)
  end

  # Un catálogo recién creado nace sin teléfono ni encargado: el papel sale
  # igual, con «—», y el equipo los llena por el CRUD de PR-M1.
  test "sin teléfono ni encargado el documento igual sale" do
    @empresa.update!(telefono: nil, encargado: nil, direccion: nil)
    get documento_manifiesto_url(@manifiesto)
    assert_response :success
    assert_match(/# tel/, response.body)
  end

  # C21-02: los rótulos que lo perdían — *"tengo que aprenderme que el tipo de
  # envío del manifiesto es el del proveedor; aquí me pierdo"*.
  test "los rótulos distinguen el tipo de envío del proveedor del nuestro" do
    get documento_manifiesto_url(@manifiesto)
    assert_match(/Tipo de envío del proveedor/, response.body)
    assert_match(/Tipo de envío nuestro/, response.body)
  end

  # C21-02: «Aduana» se imprime como la fecha en que lo recibimos en Honduras.
  test "aduana se imprime como Recibido en Honduras" do
    get documento_manifiesto_url(@manifiesto)
    assert_match(/Recibido en Honduras/, response.body)
  end

  test "lista los bultos con su código, medidas, volumen y peso" do
    caja = @manifiesto.cajas.create!(alto: 46, largo: 43, ancho: 50, peso: 120.5, user: @user)
    get documento_manifiesto_url(@manifiesto)
    assert_match(/#{caja.codigo}/, response.body)
    assert_match(/120\.5/, response.body)
  end

  test "un manifiesto sin bultos igual imprime" do
    assert_equal 0, @manifiesto.cajas.count
    get documento_manifiesto_url(@manifiesto)
    assert_response :success
    assert_match(/todavía no tiene bultos/, response.body)
  end

  # El layout `print` era solo del Warehouse Receipt y su <title> estaba fijo:
  # la pestaña del manifiesto decía «Warehouse Receipt - 1 cajas».
  test "la pestaña se llama Manifiesto, no Warehouse Receipt" do
    get documento_manifiesto_url(@manifiesto)
    assert_match(%r{<title>Manifiesto #{@manifiesto.numero}</title>}, response.body)
  end

  test "el Warehouse Receipt sigue con su propio título" do
    paquete = paquetes(:disponible_entrega_juan)
    get warehouse_receipt_paquete_url(paquete)
    assert_match(/<title>Warehouse Receipt/, response.body)
  end

  test "el botón de imprimir está en la pantalla del manifiesto" do
    get manifiesto_url(@manifiesto)
    assert_response :success
    assert_select "a[href=?]", documento_manifiesto_path(@manifiesto)
  end

  # ── C23 · La revisión del 2026-09-01 ─────────────────────────────────────

  # *"Acá esto tiene que llevar la firma de quien la recibió… firma el
  #  conductor, firma quien recepción. […] pero **debe decir firma y hora**."*
  test "C23-06 · el bloque de firmas pide nombre, firma y hora" do
    get documento_manifiesto_url(@manifiesto)

    assert_select "div.mf-firma div.rotulo", text: "Entregado por"
    assert_select "div.mf-firma div.rotulo", text: "Recibido por"
    assert_select "div.mf-firma div.linea", text: "Nombre y firma", count: 2
    assert_select "div.mf-firma div.linea", text: "Fecha y hora", count: 2
  end

  # *"«Recibido en Honduras» sí, pero eso es diferente… no necesariamente
  #  Honduras, sino quien recibió este packing."* Y el interno, que nunca pasa
  #  por Miami: *"imaginate, yo no estoy en Miami"*.
  test "C23-06 · el rótulo de las firmas no nombra ciudades" do
    get documento_manifiesto_url(@manifiesto)

    assert_no_match(/Entregado por \(Miami\)/, response.body)
    assert_no_match(/Recibido por \(Honduras\)/, response.body)
  end

  # Pero la fecha de aduana sigue arriba, que es otro dato (`C21-02`).
  test "C23-06 · «Recibido en Honduras» sigue siendo el campo del encabezado" do
    get documento_manifiesto_url(@manifiesto)

    assert_select "div.mf-h", text: "Recibido en Honduras"
  end

  # *"Y faltaría pies cúbicos también. Volumen en pies cúbicos."*
  test "C23-07 · la tabla distingue la libra volumétrica del pie cúbico" do
    @manifiesto.cajas.create!(alto: 23, largo: 23, ancho: 36, peso: 131)

    get documento_manifiesto_url(@manifiesto)

    assert_select "table.mf-t thead th", text: "Vol. (VLBS)"
    assert_select "table.mf-t thead th", text: "Pies³"
    # 23×23×36 = 19_044 in³ → 114.72 VLBS y 12 pies³ (ceil de 11.02)
    assert_select "table.mf-t tbody td.num", text: "114.72"
    assert_select "table.mf-t tbody td.num", text: "12"
  end

  # El total de pies³ suma los de cada bulto —cada uno ya redondeado hacia
  # arriba—, para que cuadre con la columna que tiene encima.
  test "C23-07 · el total de pies cúbicos suma la columna" do
    @manifiesto.cajas.create!(alto: 23, largo: 23, ancho: 36, peso: 131)   # 12
    @manifiesto.cajas.create!(alto: 13, largo: 13, ancho: 16, peso: 19)    # 2

    get documento_manifiesto_url(@manifiesto)

    assert_select "table.mf-tot td.label", text: "Pies cúbicos"
    assert_select "table.mf-tot td.value", text: "14 PIES³"
  end

  # Las unidades del total, que también eran mudas: decía «LB» y nada.
  test "C23-07 · los totales dicen en qué unidad están" do
    get documento_manifiesto_url(@manifiesto)

    assert_select "table.mf-tot td.value", text: /LBS\z/
    assert_select "table.mf-tot td.value", text: /VLBS\z/
  end

  # `C23-09` · El campo existía en la tabla, en el formulario y en la ficha,
  # pero no en el papel — que es donde Yusef lo fue a buscar.
  test "C23-09 · el documento imprime «Expedido por»" do
    @manifiesto.update!(expedido_por: "Manal Sahuri")

    get documento_manifiesto_url(@manifiesto)

    assert_match(/Expedido por:/, response.body)
    assert_match(/Manal Sahuri/, response.body)
  end

  # RP-59 · Vacío cae en las iniciales de quien lo creó. Es el caso de los
  # manifiestos de antes de la regla; los nuevos traen la columna estampada.
  test "C23-09 · sin el campo lleno cae en quien creó el manifiesto" do
    @user.update!(iniciales: "YS")
    @manifiesto.update!(expedido_por: nil, user: @user)

    get documento_manifiesto_url(@manifiesto)

    assert_match(%r{Expedido por:</strong>\s*YS}, response.body)
  end

  # **Y las dos casillas de iniciales del papel se escriben igual.** «Expedido
  # por» y «Imprimió» son la misma cosa dicha dos veces; con dos helpers
  # distintos salían `DM` y `D.M.` en el mismo documento.
  test "RP-59 · las iniciales del papel se escriben de una sola forma" do
    @user.update!(iniciales: nil, nombre: "Digitador Miami")
    @manifiesto.update!(expedido_por: nil, user: @user)

    get documento_manifiesto_url(@manifiesto)

    assert_match(%r{Expedido por:</strong>\s*DM<}, response.body)
    assert_match(%r{Imprimió:</strong>\s*DM\s*$}, response.body)
    assert_no_match(/D\.M\./, response.body, "el formato con puntos era la copia que se fue")
  end

  # *"Esta es prioridad, también un poquito más grande."*
  test "C23-08 · la píldora de prioridad crece" do
    @manifiesto.update!(es_prioridad: true)

    get documento_manifiesto_url(@manifiesto)

    assert_select "span.mf-pill", text: "ES PRIORIDAD"
    assert_match(/\.mf-pill\s*\{[^}]*font-size:\s*15px/, response.body)
  end
end
