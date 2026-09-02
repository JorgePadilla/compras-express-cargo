require "test_helper"

# C23-10 · Empacar sin escanear.
#
#   > "Vienen ellos y preparan todas estas cajas, **no les da chance de
#   >  escanear** y le empacan al puro… meten todo."
#   > "**Todos los paquetes que tienen el estatus** [recibido en Miami], **que
#   >  bajo el tipo de servicio** que se seleccionó para este [manifiesto]…
#   >  **se va a enviar sin escanear**." · "Y en el manifiesto,
#   >  **automáticamente los halás**."
#
# Lo que estos tests cuidan es que el tirón **no se lleve de más**: son tres
# filtros y cada uno tiene su test, porque un barrido masivo que agarra un
# paquete que no era mete carga ajena en un camión.
class EmpacarSinEscanearTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }

    @miami = sucursales(:miami)
    @manifiesto = manifiestos(:creado)
    @manifiesto.update!(sucursal_origen: @miami, tipo_envios: [ tipo_envios(:express) ])
  end

  # ── Lo que sí entra ──────────────────────────────────────────────────────

  test "entran los del tipo del manifiesto, recibidos en su sucursal y sin manifiesto" do
    uno = paquete_candidato(tracking: "1ZSINESC0001")
    dos = paquete_candidato(tracking: "1ZSINESC0002")

    assert_difference -> { @manifiesto.paquetes.count }, 2 do
      post empacar_sin_escanear_manifiesto_path(@manifiesto)
    end

    assert_redirected_to manifiesto_path(@manifiesto)
    assert_equal @manifiesto, uno.reload.manifiesto
    assert_equal @manifiesto, dos.reload.manifiesto
  end

  # **El estado no cambia** — decisión de Jorge, 2026-09-02. Yusef dice *"ya
  # todo fue empacado"* pero está describiendo el acto: `empacado` en este
  # sistema implica caja, y sin escaneo no hay caja
  # (`project_manifiesto_dos_caminos`).
  test "los paquetes se quedan en recibido_miami, sin caja" do
    paquete = paquete_candidato(tracking: "1ZSINESC0003")

    post empacar_sin_escanear_manifiesto_path(@manifiesto)

    paquete.reload
    assert_equal "recibido_miami", paquete.estado
    assert_nil paquete.caja_manifiesto_id
  end

  test "recalcula los totales del manifiesto" do
    paquete_candidato(tracking: "1ZSINESC0004")

    post empacar_sin_escanear_manifiesto_path(@manifiesto)

    assert_equal 1, @manifiesto.reload.cantidad_paquetes
  end

  # `update!` uno por uno y no `update_all`: es la lección que dejó escrita
  # `FinalizarManifiesto`. En un módulo donde alguien va a preguntar «¿quién
  # metió esto?», saltearse la bitácora es justo lo que no se puede hacer.
  test "deja bitácora de cada paquete que entró" do
    paquete = paquete_candidato(tracking: "1ZSINESC0005")
    antes = paquete.versions.count

    post empacar_sin_escanear_manifiesto_path(@manifiesto)

    assert_operator paquete.reload.versions.count, :>, antes,
                    "sin versión de paper_trail no se sabe quién lo metió"
  end

  # ── Los tres filtros, uno por uno ────────────────────────────────────────

  test "no entra el de otro tipo de envío" do
    ajeno = paquete_candidato(tracking: "1ZOTROTIPO01", tipo_envio: tipo_envios(:cer))

    post empacar_sin_escanear_manifiesto_path(@manifiesto)

    assert_nil ajeno.reload.manifiesto_id
  end

  test "no entra el recibido en otra sucursal" do
    ajeno = paquete_candidato(tracking: "1ZOTRASUC001", sucursal_recepcion: sucursales(:zeron_sps))

    post empacar_sin_escanear_manifiesto_path(@manifiesto)

    assert_nil ajeno.reload.manifiesto_id
  end

  test "no entra el que está en otro estado" do
    ajeno = paquete_candidato(tracking: "1ZOTROESTAD1")
    ajeno.update!(estado: "en_aduana")

    post empacar_sin_escanear_manifiesto_path(@manifiesto)

    assert_nil ajeno.reload.manifiesto_id
  end

  # Robar un paquete de otro manifiesto sería dejar dos papeles diciendo que
  # llevan la misma caja.
  test "no le roba paquetes a otro manifiesto" do
    otro = Manifiesto.create!(sucursal_origen: @miami, tipo_envios: [ tipo_envios(:express) ])
    ajeno = paquete_candidato(tracking: "1ZYAENOTRO01")
    ajeno.update!(manifiesto: otro)

    post empacar_sin_escanear_manifiesto_path(@manifiesto)

    assert_equal otro, ajeno.reload.manifiesto
  end

  # ── Cuando no hay nada ───────────────────────────────────────────────────

  # Un redirect callado dejaría al operario mirando la misma pantalla sin saber
  # si el botón hizo algo, si falló, o si de verdad no había carga.
  test "sin candidatos avisa por qué, nombrando los tres filtros" do
    post empacar_sin_escanear_manifiesto_path(@manifiesto)

    assert_match(/recibido en Miami/i, flash[:alert])
    assert_match(/#{Regexp.escape(@manifiesto.tipos_envio_nuestros)}/, flash[:alert])
    assert_match(/#{Regexp.escape(@miami.nombre)}/, flash[:alert])
  end

  # ── Dónde no aplica ──────────────────────────────────────────────────────

  # `recibido_miami` **no existe en el interno**: su carga ya llegó a Honduras.
  # Cuál es la regla equivalente ahí Yusef no la dijo, y derivarla sería
  # inventarle un criterio a un módulo que mueve el 20% de la carga.
  test "el interno no admite empacar sin escanear" do
    interno = Manifiesto.create!(tipo: "interno", sucursal_origen: sucursales(:zeron_sps),
                                 sucursal_entrega: sucursales(:humuya_tgu),
                                 tipo_envios: [ tipo_envios(:express) ])

    post empacar_sin_escanear_manifiesto_path(interno)

    assert_redirected_to manifiesto_path(interno)
    assert_match(/no admite/i, flash[:alert])
  end

  test "un manifiesto ya finalizado tampoco" do
    @manifiesto.update_column(:estado, "enviado")
    paquete = paquete_candidato(tracking: "1ZCERRADO001")

    post empacar_sin_escanear_manifiesto_path(@manifiesto)

    assert_match(/no admite/i, flash[:alert])
    assert_nil paquete.reload.manifiesto_id
  end

  # ── La pantalla ──────────────────────────────────────────────────────────

  # **El botón tiene que estar sin una sola caja**, que es el punto entero: el
  # camino sin escaneo se quedó *"porque a veces no da tiempo"*, y ahí no hay
  # casas ni pistola. Adentro del `cajas.any?` solo aparecería cuando ya no
  # hace falta.
  test "el botón aparece aunque el manifiesto no tenga ninguna caja" do
    paquete_candidato(tracking: "1ZSINCAJAS01")
    assert_empty @manifiesto.cajas

    get manifiesto_path(@manifiesto)

    assert_select "form[action=?]", empacar_sin_escanear_manifiesto_path(@manifiesto)
    assert_match(/Empacar sin escanear \(1\)/, response.body)
  end

  test "sin candidatos el botón queda deshabilitado" do
    get manifiesto_path(@manifiesto)

    assert_select "[aria-disabled=true]", { minimum: 1 }
    assert_no_match(/Empacar sin escanear \(/, response.body)
  end

  # *"O sea, aquí está empacar escaneando. Y aquí sería sin escanear."*
  test "el de la pistola dice que es escaneando" do
    @manifiesto.cajas.create!(alto: 10, largo: 10, ancho: 10, peso: 5)

    get manifiesto_path(@manifiesto)

    assert_select "a[href=?]", manifiesto_empacar_path(@manifiesto), text: /Empacar escaneando/
  end

  # *"Tienen que saber ellos qué son los que hicieron sin escanear."*
  test "la tabla distingue el que entró sin pistola del que entró en una caja" do
    sin_pistola = paquete_candidato(tracking: "1ZSINPIST001")
    sin_pistola.update!(manifiesto: @manifiesto)
    caja = @manifiesto.cajas.create!(alto: 10, largo: 10, ancho: 10, peso: 5)
    con_pistola = paquete_candidato(tracking: "1ZCONPIST001")
    con_pistola.update!(manifiesto: @manifiesto, caja_manifiesto: caja, estado: "empacado")

    get manifiesto_path(@manifiesto)

    assert_select "th", text: "Caja"
    assert_match(/sin escanear/, response.body)
    assert_match(/#{caja.letra}#{caja.numero_bulto}/, response.body)
  end

  private

  def paquete_candidato(tracking:, tipo_envio: tipo_envios(:express), sucursal_recepcion: nil)
    Paquete.create!(
      tracking: tracking,
      cliente: clientes(:juan),
      tipo_envio: tipo_envio,
      estado: "recibido_miami",
      sucursal: sucursales(:zeron_sps),                        # dónde retira
      sucursal_recepcion: sucursal_recepcion || @miami,        # dónde se recibió: lo que filtra
      peso: 10
    )
  end
end
