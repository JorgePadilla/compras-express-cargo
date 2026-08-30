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
end
