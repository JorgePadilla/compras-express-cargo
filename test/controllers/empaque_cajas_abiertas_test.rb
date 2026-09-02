require "test_helper"

# C23-11 · Empacar en varias cajas a la vez.
#
#   > "Pero aquí pues **debería de existir la múltiple** […] o sea, poder
#   >  **seleccionar las tres cajas**."
#   > "Es que **ellos arman tres cajas y empiezan a meter los paquetes en
#   >  cualquier caja**."
#   > **Jorge:** "La validación sería **mínimo uno** y…" · **Yusef:** "**máximo
#   >  todas**." · **Jorge:** "Y para desempacarlo, **lo volvemos a marcar**."
#
# **Un paquete sigue yendo en UNA caja.** Jorge preguntó lo contrario —*"un
# tracking puede tener tres cajas"*— y Yusef lo corrigió en el acto con ese
# *"no"*. Lo que hay son tres cajas llenándose al mismo tiempo. Por eso este
# archivo no prueba ninguna tabla de unión: prueba **la pantalla**.
class EmpaqueCajasAbiertasTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }

    @manifiesto = manifiestos(:creado)
    @manifiesto.update!(sucursal_origen: sucursales(:miami), tipo_envios: [ tipo_envios(:express) ])
    @a = @manifiesto.cajas.create!(alto: 10, largo: 10, ancho: 10, peso: 5)
    @b = @manifiesto.cajas.create!(alto: 10, largo: 10, ancho: 10, peso: 5)
    @c = @manifiesto.cajas.create!(alto: 10, largo: 10, ancho: 10, peso: 5)
  end

  # «Máximo todas» es el estado natural: la pantalla sirve sin configurar nada,
  # y cerrar es cómo se achica el set.
  test "por defecto están todas abiertas" do
    get manifiesto_empacar_path(@manifiesto)

    assert_response :success
    [ @a, @b, @c ].each do |caja|
      assert_select "[data-caja-id=?][data-abierta=true]", caja.id.to_s
    end
  end

  test "cerrar una la saca del set y las otras siguen abiertas" do
    post manifiesto_alternar_empaque_path(@manifiesto, @b)

    assert_response :success
    cuerpo = JSON.parse(response.body)
    assert cuerpo["ok"]
    assert_equal [ @a.id, @c.id ], cuerpo["abiertas"]

    get manifiesto_empacar_path(@manifiesto)
    assert_select "[data-caja-id=?][data-abierta=false]", @b.id.to_s
    assert_select "[data-caja-id=?][data-abierta=true]", @a.id.to_s
  end

  # *"Y para desempacarlo, lo volvemos a marcar."* Es un interruptor.
  test "volver a marcarla la abre de nuevo" do
    post manifiesto_alternar_empaque_path(@manifiesto, @b)
    post manifiesto_alternar_empaque_path(@manifiesto, @b)

    assert_includes JSON.parse(response.body)["abiertas"], @b.id
  end

  # «Mínimo uno», que Jorge propuso y Yusef ratificó. Sin ninguna abierta el
  # escaneo no tendría a dónde ir y la pantalla pediría un código que no puede
  # guardar en ningún lado.
  test "no se puede cerrar la última" do
    post manifiesto_alternar_empaque_path(@manifiesto, @b)
    post manifiesto_alternar_empaque_path(@manifiesto, @c)

    post manifiesto_alternar_empaque_path(@manifiesto, @a)

    cuerpo = JSON.parse(response.body)
    assert_not cuerpo["ok"]
    assert_match(/al menos una/i, cuerpo["mensaje"])

    get manifiesto_empacar_path(@manifiesto)
    assert_select "[data-caja-id=?][data-abierta=true]", @a.id.to_s
  end

  # Si se cierra la caja que estaba recibiendo los escaneos, el escaneo se muda
  # a otra abierta — nunca queda apuntando a una cerrada.
  test "cerrar la activa muda el escaneo a otra abierta" do
    get manifiesto_empacar_path(@manifiesto, caja_id: @b.id)
    assert_select "[data-empaque-activa-value=?]", @b.id.to_s

    post manifiesto_alternar_empaque_path(@manifiesto, @b)

    cuerpo = JSON.parse(response.body)
    assert_not_equal @b.id, cuerpo["activa"]
    assert_includes cuerpo["abiertas"], cuerpo["activa"]
  end

  # El set es de la sesión, como el tipo de envío de /etiquetar: es el estado de
  # un turno de trabajo, no un dato del manifiesto. Recargar no lo pierde.
  test "el set sobrevive a recargar la pantalla" do
    post manifiesto_alternar_empaque_path(@manifiesto, @c)

    get manifiesto_empacar_path(@manifiesto)
    assert_select "[data-caja-id=?][data-abierta=false]", @c.id.to_s

    get manifiesto_empacar_path(@manifiesto)
    assert_select "[data-caja-id=?][data-abierta=false]", @c.id.to_s
  end

  # Una caja borrada no puede quedar abierta en la sesión de nadie.
  test "una caja borrada no queda colgada en el set" do
    post manifiesto_alternar_empaque_path(@manifiesto, @c)   # quedan A y B
    @a.destroy!

    get manifiesto_empacar_path(@manifiesto)

    assert_response :success
    assert_select "[data-caja-id=?]", @b.id.to_s
    assert_select "[data-caja-id=?]", @a.id.to_s, count: 0
  end

  # ── La tabla ─────────────────────────────────────────────────────────────

  # Son tres cajas llenándose a la vez: verlas juntas es el punto. Con una sola
  # a la vista el operario no sabe cómo va el conjunto.
  test "la tabla muestra lo que hay en todas las abiertas, diciendo en cuál" do
    en_a = paquete_en(@a, "1ZENCAJAA001")
    en_c = paquete_en(@c, "1ZENCAJAC001")

    get manifiesto_empacar_path(@manifiesto)

    assert_match(/#{en_a.tracking}/, response.body)
    assert_match(/#{en_c.tracking}/, response.body)
    assert_select "th", text: "Caja"
    assert_select "td", text: "#{@a.letra}#{@a.numero_bulto}"
    assert_select "td", text: "#{@c.letra}#{@c.numero_bulto}"
  end

  test "lo que está en una caja cerrada no aparece en la tabla" do
    escondido = paquete_en(@c, "1ZCERRADA001")
    post manifiesto_alternar_empaque_path(@manifiesto, @c)

    get manifiesto_empacar_path(@manifiesto)

    assert_no_match(/#{escondido.tracking}/, response.body)
  end

  # ── Lo que NO cambió ─────────────────────────────────────────────────────

  # El modelo se queda igual: un paquete, una caja. Si esto falla es que alguien
  # leyó el audio como que el paquete va en las tres, y Yusef dijo que no.
  test "escanear sigue metiendo el paquete en una sola caja" do
    paquete = paquete_candidato("1ZUNACAJA001")

    post manifiesto_escanear_empaque_path(@manifiesto, @b),
         params: { codigo: paquete.numero_recepcion }, as: :json

    assert_equal "ok", JSON.parse(response.body)["resultado"]
    assert_equal @b.id, paquete.reload.caja_manifiesto_id
  end

  # Y la fila que vuelve dice en qué caja cayó, que es lo que la tabla necesita
  # ahora que muestra varias.
  test "la fila que contesta el escaneo trae la caja" do
    paquete = paquete_candidato("1ZUNACAJA002")

    post manifiesto_escanear_empaque_path(@manifiesto, @b),
         params: { codigo: paquete.numero_recepcion }, as: :json

    assert_equal "#{@b.letra}#{@b.numero_bulto}", JSON.parse(response.body).dig("fila", "caja")
  end

  private

  def paquete_candidato(tracking)
    Paquete.create!(tracking: tracking, cliente: clientes(:juan),
                    tipo_envio: tipo_envios(:express), estado: "recibido_miami",
                    sucursal: sucursales(:zeron_sps), sucursal_recepcion: sucursales(:miami),
                    peso: 10)
  end

  def paquete_en(caja, tracking)
    paquete_candidato(tracking).tap do |p|
      p.update!(caja_manifiesto: caja, manifiesto: @manifiesto, estado: "empacado")
    end
  end
end
