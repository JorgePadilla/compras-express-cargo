require "test_helper"

# PR-C6.5: todo paquete etiquetado nace con número de recepción.
#
# El hallazgo que destapó esto: **`/etiquetar` nunca asignaba sucursal.** Cero
# menciones en el controller y cero en la vista. Y `generate_numero_recepcion`
# sale temprano con `return if origen.nil?`, así que la correlación en la base
# era perfecta — 45 paquetes sin sucursal, los mismos 45 sin número.
#
# Consecuencia: la etiqueta caía a `numero_recepcion.presence || tracking` y
# **imprimía el tracking en el código de barras**, que es justo lo que Yusef
# prohibió: "el código de barra que está aquí es el warehouse, no es el
# tracking".
#
# La raíz era un choque de significados: `paquetes.sucursal_id` era a la vez
# "dónde retira el cliente" (etiqueta, listado, búsqueda de tarifa) y "de dónde
# sale el prefijo del número" (`RMI` = Recibido Miami). Un paquete se recibe en
# Miami y se retira en Zeron SPS; una columna no puede ser las dos.
class EtiquetarSucursalRecepcionTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @tipo = tipo_envios(:cer)
    @miami = sucursales(:miami)
  end

  test "el paquete etiquetado nace con numero de recepcion" do
    iniciar_sesion_etiquetado

    assert_difference -> { Paquete.count }, 1 do
      post etiquetar_url, params: { paquete: attrs_validos }
    end

    p = Paquete.order(:id).last
    assert_equal @miami, p.sucursal_recepcion
    assert p.numero_recepcion.present?, "el paquete nació sin número de recepción"
    assert p.numero_recepcion.start_with?("R#{@miami.codigo}"),
           "el número no lleva el código de la sucursal donde se recibió"
  end

  test "recibir NO define donde retira el cliente" do
    # La razón de ser de la columna nueva. Si esto se rompe, la etiqueta
    # vuelve a decir "RETIRA EN: Miami" para un cliente de San Pedro, y la
    # búsqueda de tarifa queda atada a Miami.
    iniciar_sesion_etiquetado

    post etiquetar_url, params: { paquete: attrs_validos }

    p = Paquete.order(:id).last
    assert_equal @miami, p.sucursal_recepcion
    assert_nil p.sucursal, "sucursal es 'dónde retira', no debe tocarse al recibir"
  end

  test "las N cajas de un split comparten el numero madre" do
    iniciar_sesion_etiquetado

    assert_difference -> { Paquete.count }, 3 do
      # PR-C7.17: las cajas se agregan una por una; la cantidad sale de contar
      # las filas, no de un campo.
      post etiquetar_url, params: {
        paquete: attrs_validos.merge(cajas: { "1" => { peso: 5 }, "2" => { peso: 8 },
                                              "3" => { peso: 2 } })
      }
    end

    cajas = Paquete.order(:id).last(3)
    numeros = cajas.map(&:numero_recepcion).uniq
    assert_equal 1, numeros.size, "las cajas del split tienen números distintos"
    assert numeros.first.present?
    assert_equal [ 1, 2, 3 ], cajas.map(&:numero_caja).sort
    assert cajas.all? { |c| c.sucursal_recepcion == @miami }
  end

  test "el contador avanza una sola vez por split, no N" do
    iniciar_sesion_etiquetado
    contador = -> { NumeroRecepcionCounter.find_by(sucursal: @miami, anio: Time.zone.now.year)&.ultimo_numero.to_i }

    antes = contador.call
    post etiquetar_url, params: { paquete: attrs_validos.merge(cajas: { "1" => { peso: 5 }, "2" => { peso: 5 }, "3" => { peso: 5 }, "4" => { peso: 5 } }) }

    assert_equal antes + 1, contador.call, "el split consumió 4 números en vez de 1"
  end

  test "con una sola sucursal no pregunta nada" do
    # El caso de hoy: `/etiquetar` es solo para Miami, así que el operario no
    # tiene nada que elegir y la sucursal viaja en un hidden.
    get etiquetar_url
    assert_response :success

    assert_match(/name="sucursal_recepcion_id"[^>]*type="hidden"|type="hidden"[^>]*name="sucursal_recepcion_id"/,
                 response.body, "debería mandar la sucursal en un hidden")
    assert_no_match(/<select[^>]*name="sucursal_recepcion_id"/, response.body,
                    "con una sola opción no hay nada que preguntar")
  end

  # ── C18-02 · dónde se recibe carga, no dónde está el usuario ──────────

  test "un admin de Honduras ve Miami, no San Pedro" do
    # El caso de Yusef: su admin está en `honduras` y el chooser filtraba por la
    # ubicación del usuario, así que le ofrecía las tres de Honduras y le
    # escondía Miami. "Aquí te falta Miami… el que está oculto es el que va a
    # recibir." Y el número de su etiqueta salió `RSPS…`.
    admin = users(:admin)
    assert_equal "honduras", admin.ubicacion, "el test necesita un usuario de Honduras"
    post session_url, params: { email_address: admin.email_address, password: "password123" }

    get etiquetar_url
    assert_response :success
    assert_match(/name="sucursal_recepcion_id"[^>]*value="#{@miami.id}"|value="#{@miami.id}"[^>]*name="sucursal_recepcion_id"/,
                 response.body, "Miami tiene que ser la de recepción, aunque el usuario esté en Honduras")
    assert_no_match(/value="#{sucursales(:zeron_sps).id}"[^>]*name="sucursal_recepcion_id"|name="sucursal_recepcion_id"[^>]*value="#{sucursales(:zeron_sps).id}"/,
                    response.body, "San Pedro entrega, no recibe")

    post iniciar_sesion_etiquetar_url, params: { tipo_envio_id: @tipo.id }
    post etiquetar_url, params: { paquete: attrs_validos }
    p = Paquete.order(:id).last
    assert_equal @miami, p.sucursal_recepcion
    assert p.numero_recepcion.start_with?("R#{@miami.codigo}"), "el número salió de Honduras: #{p.numero_recepcion}"
  end

  test "una sucursal de otro pais marcada como recibe carga aparece, y la del usuario queda preseleccionada" do
    # "Sería bueno tener otro como de prueba, tipo México." México es `otros`,
    # ubicación que ningún usuario tiene: por eso no puede derivarse de la
    # ubicación, tiene que ser el checkbox.
    mexico = Sucursal.create!(codigo: "MEX", nombre: "México", pais: "México", ubicacion: "otros",
                              codigo_recepcion_prefix: "RMX", activo: true, recibe_carga: true)

    get etiquetar_url
    assert_response :success
    assert_match(/<select[^>]*name="sucursal_recepcion_id"/, response.body, "con dos, hay que preguntar")
    assert_match(/<option[^>]*value="#{mexico.id}"/, response.body)
    assert_match(/<option selected="selected" value="#{@miami.id}"/, response.body,
                 "el digitador está en Miami: esa va preseleccionada")
  end

  test "una sucursal inactiva no se ofrece aunque reciba carga" do
    Sucursal.create!(codigo: "MEX", nombre: "México", pais: "México", ubicacion: "otros",
                     codigo_recepcion_prefix: "RMX", activo: false, recibe_carga: true)

    get etiquetar_url
    assert_no_match(/<select[^>]*name="sucursal_recepcion_id"/, response.body)
  end

  test "un id de una sucursal que no recibe cae al default" do
    # San Pedro existe y está activa, pero entrega, no recibe: posteada a mano
    # no puede abrir sesión ahí.
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: @tipo.id, sucursal_recepcion_id: sucursales(:zeron_sps).id }

    post etiquetar_url, params: { paquete: attrs_validos }
    assert_equal @miami, Paquete.order(:id).last.sucursal_recepcion
  end

  test "un sucursal_recepcion_id invalido cae al default en vez de reventar" do
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: @tipo.id, sucursal_recepcion_id: 999_999 }

    assert_redirected_to etiquetar_path

    post etiquetar_url, params: { paquete: attrs_validos }
    p = Paquete.order(:id).last
    assert p.sucursal_recepcion.present?, "quedó sin sucursal de recepción"
    assert p.numero_recepcion.present?
  end

  test "finalizar sesion olvida la sucursal" do
    iniciar_sesion_etiquetado
    delete finalizar_sesion_etiquetar_url

    get etiquetar_url
    assert_response :success
    # Sin sesión, la pantalla vuelve a preguntar el tipo de envío.
    assert_match(/tipo de envío vas a trabajar/i, response.body)
  end

  # ── Lo que NO se puede romper ──────────────────────────────────────────

  test "un paquete creado fuera de etiquetar sigue numerandose por su sucursal" do
    # El fallback existe por esto: alta manual desde /paquetes, seeds y
    # fixtures no pasan por la sesión de etiquetado y ahí la única sucursal
    # que hay es `sucursal`. Sin el fallback esos paquetes se quedarían sin
    # número — el mismo bug, del otro lado.
    p = Paquete.create!(
      tracking: "SINSESION#{SecureRandom.hex(3)}",
      cliente: clientes(:juan),
      sucursal: @miami,
      estado: "recibido_miami",
      user: @user
    )

    assert p.numero_recepcion.present?
    assert p.numero_recepcion.start_with?("R#{@miami.codigo}")
  end

  test "la sucursal de recepcion manda sobre la de retiro" do
    p = Paquete.create!(
      tracking: "AMBAS#{SecureRandom.hex(3)}",
      cliente: clientes(:juan),
      sucursal: sucursales(:zeron_sps),   # retira en San Pedro
      sucursal_recepcion: @miami,          # se recibió en Miami
      estado: "recibido_miami",
      user: @user
    )

    assert p.numero_recepcion.start_with?("R#{@miami.codigo}"),
           "el número salió de dónde retira en vez de dónde se recibió"
  end

  # ── Seguimiento de C18-02 (2026-08-27) ──────────────────────────────────
  # Jorge: *"Miami es el default pero podría ser DF México"*. Con dos que
  # reciben, `posibles.first` era el orden por nombre: «DF México» antes que
  # «Miami», y el admin de Honduras (Yusef) la veía preseleccionada.

  test "el admin de Honduras con Miami y DF Mexico ve Miami preseleccionada, no la primera por nombre" do
    mexico = crear_df_mexico
    entrar users(:admin)

    get etiquetar_url

    assert_match(/<select[^>]*name="sucursal_recepcion_id"/, response.body)
    assert_match(/<option selected="selected" value="#{@miami.id}"/, response.body,
                 "«DF México» ordena antes que «Miami» y le robaba el default")
    assert_no_match(/<option selected="selected" value="#{mexico.id}"/, response.body)
  end

  test "un usuario con DF Mexico asignada la ve preseleccionada aunque Miami sea la de por defecto" do
    mexico = crear_df_mexico
    @user.update!(sucursal: mexico)

    get etiquetar_url

    assert_match(/<option selected="selected" value="#{mexico.id}"/, response.body)
  end

  test "un usuario cuya sucursal no recibe carga cae a la de por defecto" do
    crear_df_mexico
    @user.update!(sucursal: sucursales(:zeron_sps))

    get etiquetar_url

    assert_match(/<option selected="selected" value="#{@miami.id}"/, response.body)
  end

  private

  def crear_df_mexico
    Sucursal.create!(codigo: "DFM", codigo_ep: "SDF", nombre: "DF México", pais: "México",
                     ubicacion: "otros", activo: true, recibe_carga: true)
  end

  def entrar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def iniciar_sesion_etiquetado
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: @tipo.id, sucursal_recepcion_id: @miami.id }
  end

  def attrs_validos
    {
      tracking: "REC#{SecureRandom.hex(4)}",
      cliente_id: clientes(:juan).id,
      descripcion: "Paquete de prueba",
      peso: 5
    }
  end
end
