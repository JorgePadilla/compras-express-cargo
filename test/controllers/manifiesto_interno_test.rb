require "test_helper"

# `A7-07` · El manifiesto **interno** de sucursal.
#
# Yusef, Conversación 7: *"es el de envío nacional, de una sucursal a la otra.
# Lleva un **manifiesto interno** y es igualito."*
#
# Igualito en cómo se opera —se arma, se cierra, se recibe escaneando— y
# distinto en qué lleva: **no cruza aduana**, así que consignatario, empresa
# proveedora, tipo de envío del proveedor, guía y fecha de aduana no le aplican.
# Mueve el ~20% de la carga: *"el 80% de la carga se queda en San Pedro"*.
class ManifiestoInternoTest < ActionDispatch::IntegrationTest
  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def crear_interno(**attrs)
    Manifiesto.create!(
      tipo: "interno",
      sucursal_origen: sucursales(:zeron_sps),
      sucursal_entrega: sucursales(:humuya_tgu),
      tipo_envios: [ tipo_envios(:cer) ],
      **attrs
    )
  end

  # ── Lo que el tipo cambia ───────────────────────────────────────────────

  test "el oficial sigue siendo el default: lo que ya existía no se movió" do
    m = Manifiesto.create!(sucursal_origen: sucursales(:miami),
                           tipo_envios: [ tipo_envios(:cer) ])

    assert m.tipo_oficial?
    assert_not m.tipo_interno?
  end

  test "el interno exige a qué sucursal va" do
    m = Manifiesto.new(tipo: "interno", sucursal_origen: sucursales(:zeron_sps),
                       tipo_envios: [ tipo_envios(:cer) ])

    assert_not m.valid?, "sin sucursal de entrega no se sabe a dónde va el camión"
    assert_includes m.errors.attribute_names, :sucursal_entrega
  end

  test "el oficial no la exige, que es como estaba" do
    m = Manifiesto.new(sucursal_origen: sucursales(:miami),
                       tipo_envios: [ tipo_envios(:cer) ])

    assert m.valid?
  end

  # ── Lo que motivó filtrarlo ─────────────────────────────────────────────
  #
  # Sin el filtro, cada envío de SPS a Tegucigalpa aparecería en
  # `/guias-y-aduana` como «le falta la guía» y **no se iría nunca de la lista**:
  # un manifiesto interno no tiene guía de proveedor ni fecha de aduana, y no las
  # va a tener.

  test "el interno no aparece esperando guía ni fecha de aduana" do
    interno = crear_interno(estado: "enviado")

    assert_not_includes Manifiesto.esperando_datos_de_san_pedro, interno
  end

  test "el oficial sí aparece, y por eso el filtro no es de más" do
    oficial = Manifiesto.create!(sucursal_origen: sucursales(:miami), estado: "enviado",
                                 tipo_envios: [ tipo_envios(:cer) ])

    assert_includes Manifiesto.esperando_datos_de_san_pedro, oficial
  end

  test "la pantalla de guías y aduana tampoco lo lista, ni con todos=1" do
    interno = crear_interno(estado: "enviado")
    ingresar(users(:supervisor_prefactura))

    get guias_aduana_index_url
    assert_select "body" do
      assert_select "*", { text: /#{interno.numero}/, count: 0 },
                    "el interno no tiene guía que llenar: no va en esa lista"
    end

    get guias_aduana_index_url(todos: 1)
    assert_select "*", { text: /#{interno.numero}/, count: 0 },
                  "tampoco en «todos»: ahí quedaría como pendiente eterno"
  end

  # ── El formulario ───────────────────────────────────────────────────────

  test "se crea desde la pantalla eligiendo el tipo" do
    ingresar(users(:supervisor_miami))

    assert_difference "Manifiesto.count", 1 do
      post manifiestos_url, params: { manifiesto: {
        tipo: "interno",
        sucursal_origen_id: sucursales(:zeron_sps).id,
        sucursal_entrega_id: sucursales(:humuya_tgu).id,
        tipo_envio_ids: [ tipo_envios(:cer).id ]
      } }
    end

    assert Manifiesto.last.tipo_interno?
  end

  test "el número sale con el código de la sucursal que lo arma" do
    m = crear_interno

    assert_match(/\AMSPS#{Time.zone.now.year}\d{6}\z/, m.numero,
                 "el interno numera por su sucursal de origen, como cualquier otro")
  end

  # ── Los dos conviven ────────────────────────────────────────────────────

  test "un interno y un oficial de sucursales distintas no chocan de número" do
    interno = crear_interno
    oficial = Manifiesto.create!(sucursal_origen: sucursales(:miami),
                                 tipo_envios: [ tipo_envios(:cer) ])

    assert_not_equal interno.numero, oficial.numero
  end

  test "el listado marca cuál es interno y a dónde va" do
    interno = crear_interno
    ingresar(users(:supervisor_miami))

    get manifiestos_url

    assert_select "body", text: /#{interno.numero}/
    assert_select "body", { text: /interno/ },
                  "sin la marca, en el listado son indistinguibles"
  end
end
