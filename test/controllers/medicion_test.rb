require "test_helper"

# C26-02 · La estación de Medición, por JSON.
#
# Lo que Jorge corrigió de la primera versión: el escaneo no responde una caja,
# responde **el grupo**, con los dos lados del dato — *"cómo está en la
# pre-alerta y cómo ingresó en Miami"*.
class MedicionTest < ActionDispatch::IntegrationTest
  setup do
    @medidor = users(:medidor)
    @medidor.update!(iniciales: "MD")
    ingresar(@medidor)
    @paquete = caja("1ZMEDIR00000001")
  end

  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def caja(tracking, estado: "en_aduana", cliente: clientes(:juan), **extra)
    Paquete.create!(tracking: tracking, cliente: cliente, tipo_envio: tipo_envios(:cer),
                    sucursal_recepcion: sucursales(:miami), estado: estado, descripcion: "Zapatos", peso: 2, **extra)
  end

  def escanear(codigo) = post(escanear_medicion_index_path, params: { codigo: codigo }, as: :json)
  def medir(paquete, peso: "12.5", alto: "10", largo: "12", ancho: "14")
    patch medir_medicion_path(paquete), params: { peso: peso, alto: alto, largo: largo, ancho: ancho }, as: :json
  end
  def json = JSON.parse(response.body)

  # ── Los dos lados del dato ───────────────────────────────────────────────

  test "el escaneo dice cómo ingresó Miami" do
    @paquete.update!(fecha_recibido_miami: Time.zone.parse("2026-09-01 09:00"), user: users(:digitador))
    users(:digitador).update!(iniciales: "DM")

    escanear(@paquete.tracking)

    assert_equal "ok", json["resultado"]
    miami = json["miami"]
    assert_equal @paquete.reload.numero_recepcion, miami["wr"]
    assert_equal "01/09/2026", miami["recibido"]
    assert_equal "DM", miami["por"]
    assert_equal "Zapatos", miami["descripcion"]
    assert_not miami["retenido"]
  end

  test "y dice cómo lo declaró el cliente, que puede ser otra cosa" do
    pa, = grupo_de_tres(@paquete)
    escanear(@paquete.tracking)

    declarado = json["pre_alerta"]
    assert_equal pa.numero_documento, declarado["numero"]
    assert_equal 3, declarado["trackings"]
    assert declarado["consolidado"]
    assert_equal "Consolidado de prueba", declarado["titulo"]
    assert_not_equal declarado["tipo_envio"], json["miami"]["tipo_envio"],
                     "el tipo con el que Miami lo ingresó no es el que el cliente declaró, y las dos cosas se ven"
  end

  # ── La grilla ────────────────────────────────────────────────────────────

  test "la grilla trae un cuadrito por caja, con su estado y cuál está seleccionada" do
    _pa, otros = grupo_de_tres(@paquete)
    llego(otros.first)

    escanear(@paquete.tracking)

    grupo = json["grupo"]
    assert grupo["consolidada"]
    assert_equal [ 3, 0, 2 ], grupo.values_at("total", "medidas", "llegadas")
    assert_equal %w[aqui aqui esperada], grupo["cajas"].map { |c| c["estado"] }
    assert_equal [ true, false, false ], grupo["cajas"].map { |c| c["seleccionada"] }
    assert_equal [ true, true, false ], grupo["cajas"].map { |c| c["medible"] }
    assert_nil grupo["cajas"].last["wr"], "lo que Miami no tiene no tiene warehouse receipt"
    assert_equal "no ha llegado a Miami", grupo["cajas"].last["donde"]
  end

  test "un tracking partido en tres cajas son tres cuadritos, aunque la pre-alerta tenga un renglón" do
    @paquete.update!(cantidad_paquetes: 3, numero_caja: 1)
    hermanas = (2..3).map { |n| hermana(@paquete, n) }

    escanear(@paquete.reload.numero_recepcion + "-1")

    grupo = json["grupo"]
    assert_equal 3, grupo["total"]
    assert_not grupo["consolidada"], "no lo pidió el cliente: viene partido"
    assert_equal hermanas.map(&:id), grupo["cajas"].drop(1).map { |c| c["id"] }
  end

  # ── Medir y las stickers juntas ──────────────────────────────────────────

  test "medir una caja de un grupo incompleto no imprime todavía" do
    grupo_de_tres(@paquete)

    medir(@paquete)

    assert_equal "medido", json["resultado"]
    assert_nil json["imprimir_url"], "las stickers salen juntas al completar el grupo"
    assert_equal 1, json["grupo"]["medidas"]
    assert_equal "medida", json["grupo"]["cajas"].first["estado"]
  end

  test "al medir la última salen las etiquetas del grupo, juntas" do
    pa, otros = grupo_de_tres(@paquete)
    medir(@paquete)
    otros.each { |p| medir(llego(p)) }

    assert_equal "grupo_completo", json["resultado"]
    assert_match(/3 de 3 medidas/, json["mensaje"])
    assert_equal etiquetas_grupo_medicion_path(pa, print: "true"), json["imprimir_url"]

    get json["imprimir_url"]
    assert_response :success
    assert_equal 3, response.body.scan(/class="med"/).size, "una sticker por caja"
  end

  test "una caja sola imprime la suya al guardarla" do
    medir(@paquete)

    assert_equal etiqueta_medicion_path(@paquete, print: "true"), json["imprimir_url"]
  end

  test "las etiquetas del grupo son solo las medidas" do
    pa, = grupo_de_tres(@paquete)
    medir(@paquete)

    get etiquetas_grupo_medicion_path(pa)
    assert_response :success
    assert_equal 1, response.body.scan(/class="med"/).size, "una caja sin medir no lleva sticker"
  end

  # ── Facturar lo que hay, sin PIN ─────────────────────────────────────────

  test "pasar sin el grupo completo no pide PIN, y queda anotado" do
    pa, = grupo_de_tres(@paquete)
    medir(@paquete)

    post facturar_parcial_medicion_path(pa), as: :json

    assert_response :success
    assert_equal "MD", pa.reload.union_parcial_por
    assert_equal "MD", json["grupo"]["parcial_autorizado"]["por"]
    assert_match(/1ZFALTA/, pa.historial)
    assert_equal etiquetas_grupo_medicion_path(pa, print: "true"), json["imprimir_url"]
  end

  test "con el grupo completo, forzarlo es 422" do
    pa, otros = grupo_de_tres(@paquete)
    medir(@paquete)
    otros.each { |p| medir(llego(p)) }

    post facturar_parcial_medicion_path(pa), as: :json

    assert_response :unprocessable_entity
    assert_match(/completo/, json["errores"].join)
  end

  # ── Lo que no se mide ────────────────────────────────────────────────────

  test "lo que no se encuentra, lo que no llegó y lo que ya está facturado se dicen distinto" do
    escanear("NOEXISTE123")
    assert_equal "no_encontrado", json["resultado"]

    escanear(caja("1ZNOLLEGO0000001", estado: "enviado_honduras").tracking)
    assert_equal "no_esta_en_honduras", json["resultado"]
    assert_match(/Recibir Carga/, json["mensaje"])

    @paquete.update_columns(pre_factura_id: PreFactura.first.id)
    escanear(@paquete.tracking)
    assert_equal "en_pre_factura", json["resultado"]
  end

  test "una caja de una pre-alerta ya facturada avisa, y se deja medir" do
    cerrada = pre_alertas(:finalizada)
    cerrada.pre_alerta_paquetes.create!(tracking: @paquete.tracking, descripcion: "Tarde",
                                        fecha: Date.current, paquete: @paquete)

    escanear(@paquete.tracking)
    assert_equal "pre_alerta_ya_facturada", json["resultado"]
    assert_match(/partir la pre-alerta/, json["mensaje"])

    medir(@paquete)
    assert_response :success
  end

  test "una caja ya medida avisa quién y cuándo" do
    @paquete.update!(medido_at: Time.zone.parse("2026-09-06 10:22"), medido_por: "SP", alto: 10, largo: 12, ancho: 14)

    escanear(@paquete.tracking)

    assert_equal "SP", json["medicion_previa"]["por"]
    assert_match(%r{06/09/2026}, json["medicion_previa"]["fecha"])
  end

  # C26-18 · La regla dejó de ser «los cuatro» y pasó a ser «al menos uno».
  # Yusef: *"a veces no se mide, cuando es una cajita bien pequeñita; pero
  # siempre una de estas cuatro se mete"*.
  test "todo en blanco es 422 con el porqué" do
    medir(@paquete, peso: "", alto: "", largo: "", ancho: "")

    assert_response :unprocessable_entity
    assert_match(/al menos el peso/, json["errores"].join)
    assert_nil @paquete.reload.medido_at
  end

  test "dos de tres medidas es 422: sin volumétrico no hay qué comparar" do
    medir(@paquete, peso: "12.5", alto: "", largo: "12", ancho: "14")

    assert_response :unprocessable_entity
    assert_match(/las tres/, json["errores"].join)
    assert_nil @paquete.reload.medido_at
  end

  # La caja chiquita que solo va a la báscula: antes esto era un 422 y la
  # estación quedaba trabada.
  test "solo el peso alcanza para medir" do
    medir(@paquete, peso: "2.5", alto: "", largo: "", ancho: "")

    assert_response :success
    assert_equal 2.5, @paquete.reload.peso.to_f
    assert_not_nil @paquete.medido_at
  end

  # ── Quién entra ──────────────────────────────────────────────────────────

  test "el rol medición entra a su estación y a nada más" do
    get medicion_index_path
    assert_response :success

    [ paquetes_path, pre_alertas_path, clientes_path, tareas_path ].each do |ruta|
      get ruta
      assert_response :redirect, "#{ruta}: «no se les habilita nada más que eso»"
    end
  end

  test "la raíz lo manda a su estación; Honduras entra y Miami no" do
    get root_path
    assert_redirected_to medicion_index_path

    ingresar(users(:cajero))
    get medicion_index_path
    assert_response :success

    ingresar(users(:digitador))
    get medicion_index_path
    assert_redirected_to root_path
  end


  # ── C26-02 · El warehouse receipt de un envío partido ────────────────────
  #
  # Jorge, escaneando: *"esto no debería salir: «es un envío de 3 cajas,
  # escaneá la etiqueta de la caja». Escaneé el warehouse receipt y me deberían
  # aparecer los datos de los otros paquetes."* Varias cajas con el mismo
  # warehouse receipt **no son una ambigüedad**: son un envío partido.

  test "escanear el warehouse receipt de un envío de tres cajas trae las tres" do
    cajas = envio_partido(@paquete, 3)

    escanear(@paquete.reload.numero_recepcion)

    assert_equal "ok", json["resultado"]
    assert_equal cajas.first.id, json["paquete"]["id"], "se mide la primera sin medir"
    assert_equal 3, json["grupo"]["total"]
    assert_equal cajas.map(&:id), json["grupo"]["cajas"].map { |c| c["id"] }
    assert_match(/3 cajas con este warehouse receipt/, json["mensaje"])
    assert_match(/vas por la 1 de 3/, json["mensaje"])
  end

  test "con la primera medida, el mismo warehouse receipt trae la segunda" do
    cajas = envio_partido(@paquete, 3)
    medir(cajas.first)

    escanear(@paquete.reload.numero_recepcion)

    assert_equal cajas.second.id, json["paquete"]["id"]
    assert_equal "medida", json["grupo"]["cajas"].first["estado"]
    assert_match(/vas por la 2 de 3/, json["mensaje"])
  end

  test "cada cuadrito dice de qué envío es, para poder encadenar las cajas" do
    envio_partido(@paquete, 2)

    escanear(@paquete.reload.numero_recepcion)

    assert_equal [ @paquete.numero_recepcion ] * 2, json["grupo"]["cajas"].map { |c| c["envio"] }
    assert_equal @paquete.numero_recepcion, json["paquete"]["wr"]
  end

  test "al medir la última del envío salen las stickers de las tres" do
    cajas = envio_partido(@paquete, 3)
    cajas.first(2).each { |c| medir(c) }
    assert_nil json["imprimir_url"], "todavía falta una"

    medir(cajas.last)

    assert_equal "grupo_completo", json["resultado"]
    assert_equal etiqueta_medicion_path(cajas.first, hermanas: "1", print: "true"), json["imprimir_url"]
    get json["imprimir_url"]
    assert_equal 3, response.body.scan(/class="med"/).size
  end

  # La ambigüedad de verdad: un código que cae en **envíos distintos**.
  test "un código que aparece en dos envíos distintos sí es ambiguo" do
    otro = caja("1ZMEDIR00000001")   # mismo tracking, otro warehouse receipt

    escanear("1ZMEDIR00000001")

    assert_equal "ambiguo", json["resultado"]
    assert_match(/envíos distintos/, json["mensaje"])
    assert_match(/#{@paquete.reload.numero_recepcion}/, json["mensaje"])
    assert_not_equal @paquete.numero_recepcion, otro.reload.numero_recepcion
  end

  test "el grupo se arma aunque Miami no haya puesto la cantidad de cajas" do
    hermana(@paquete, nil).update_columns(cantidad_paquetes: nil, numero_caja: nil)
    @paquete.update_columns(cantidad_paquetes: nil, numero_caja: nil)

    escanear(@paquete.reload.numero_recepcion)

    assert_equal "ok", json["resultado"]
    assert_equal 2, json["grupo"]["total"], "comparten warehouse receipt: son el mismo envío"
  end

  # C26-04 · El bug que Jorge vio: *"«Reimprimir el grupo» veo que solo imprime
  # una"*. `etiqueta` decidía si traía las hermanas con `dividido?`, que mira
  # `cantidad_paquetes` — el mismo campo que ayer se sacó de `GrupoDeUnion`
  # porque puede venir vacío, y que había quedado vivo acá.
  test "reimprimir el envío trae todas las medidas, aunque falte la cantidad de cajas" do
    cajas = envio_partido(@paquete, 3)
    cajas.each { |c| medir(c) }
    Paquete.where(id: cajas.map(&:id)).update_all(cantidad_paquetes: nil)

    get etiqueta_medicion_path(cajas.first, hermanas: "1")

    assert_response :success
    assert_equal 3, response.body.scan(/class="med"/).size,
                 "son tres cajas del mismo warehouse receipt: van las tres stickers"
  end

  test "y solo las medidas: una caja sin medir no lleva sticker" do
    cajas = envio_partido(@paquete, 3)
    cajas.first(2).each { |c| medir(c) }

    get etiqueta_medicion_path(cajas.first, hermanas: "1")

    assert_equal 2, response.body.scan(/class="med"/).size
  end

  # ── C26-17 · El panel de lo que falta del manifiesto ─────────────────────
  #
  # Jorge: *"¿cómo ayuda eso de «medidos hoy»? Sería bueno que aparezcan los que
  # faltan de ese manifiesto, así como match con lo que se mandó desde Miami…
  # y la fecha de cuándo fue enviado"*.

  test "el escaneo trae el manifiesto, con el match de lo que Miami mandó" do
    manifiesto = manifiesto_con(@paquete, otras: 2)

    escanear(@paquete.tracking)

    m = json["manifiesto"]
    assert_equal manifiesto.numero, m["numero"]
    assert_equal "20/08/2026", m["enviado"]
    assert_equal [ 3, 0, 3 ], m.values_at("enviados", "medidos", "faltan")
    assert_equal 3, m["pendientes"].size
    assert m["pendientes"].first["midiendo"], "el que se está midiendo se marca"
  end

  test "medir baja el contador y saca la caja de los pendientes" do
    manifiesto_con(@paquete, otras: 2)

    medir(@paquete)

    m = json["manifiesto"]
    assert_equal [ 3, 1, 2 ], m.values_at("enviados", "medidos", "faltan")
    assert_not_includes m["pendientes"].map { |p| p["id"] }, @paquete.id
  end

  test "los pendientes dicen cuáles vienen consolidados, sin escanearlos" do
    manifiesto = manifiesto_con(@paquete, otras: 1)
    otra = manifiesto.paquetes.where.not(id: @paquete.id).first
    pa = PreAlerta.create!(numero_documento: "PA-TUNIR1", cliente: clientes(:juan), tipo_envio: tipo_envios(:aereo),
                           consolidado: true, estado: "pre_alerta", titulo: "Consolidado",
                           creado_por_tipo: "usuario", creado_por_id: users(:admin).id)
    pa.pre_alerta_paquetes.create!(tracking: otra.tracking, descripcion: "x", fecha: Date.current, paquete: otra)

    get panel_medicion_index_path

    pendientes = json["manifiesto"]["pendientes"].index_by { |p| p["id"] }
    assert_equal "PA-TUNIR1", pendientes[otra.id]["unir"]
    assert_nil pendientes[@paquete.id]["unir"]
  end

  test "lo que no llegó a Honduras va en la lista, aparte" do
    manifiesto = manifiesto_con(@paquete, otras: 1)
    manifiesto.paquetes.where.not(id: @paquete.id).first.update!(estado: "enviado_honduras")

    get panel_medicion_index_path

    pendientes = json["manifiesto"]["pendientes"]
    assert_equal [ true, false ], pendientes.map { |p| p["aqui"] }, "primero lo que se puede medir"
    assert_equal "no llegó a Honduras", pendientes.last["donde"]
  end

  # ── Sacar de la lista: solo admin ────────────────────────────────────────

  test "el operario de medición no puede sacar nada de la lista" do
    manifiesto_con(@paquete, otras: 1)

    post descartar_medicion_path(@paquete), params: { motivo: "perdido" }, as: :json

    assert_response :forbidden
    assert_not @paquete.reload.descartado_de_medicion?
  end

  test "el admin la saca con su motivo, y deja de contarse como faltante" do
    manifiesto_con(@paquete, otras: 1)
    users(:admin).update!(iniciales: "AD")
    ingresar(users(:admin))

    post descartar_medicion_path(@paquete), params: { motivo: "perdido", nota: "no apareció" }, as: :json

    assert_response :success
    assert_equal "AD", @paquete.reload.medicion_descartada_por
    m = json["manifiesto"]
    assert_equal [ 2, 0, 1, 1 ], m.values_at("enviados", "medidos", "faltan", "descartados")
    assert_not_includes m["pendientes"].map { |p| p["id"] }, @paquete.id
    assert_match(/salió de la lista: perdido/, json["mensaje"])
  end

  test "el admin también puede devolverla a la lista" do
    manifiesto_con(@paquete, otras: 1)
    ingresar(users(:admin))
    post descartar_medicion_path(@paquete), params: { motivo: "entregado" }, as: :json

    delete restaurar_medicion_path(@paquete), as: :json

    assert_response :success
    assert_not @paquete.reload.descartado_de_medicion?
    assert_includes json["manifiesto"]["pendientes"].map { |p| p["id"] }, @paquete.id
  end

  private


  # Un envío partido de verdad: todas las cajas comparten el warehouse receipt
  # (el «número madre») y cada una lleva el suyo, como hace `crear_split!`.
  def envio_partido(madre, n)
    madre.update!(cantidad_paquetes: n, numero_caja: 1)
    [ madre.reload, *(2..n).map { |i| hermana(madre, i) } ]
  end

  # Una pre-alerta consolidada de Juan con tres trackings: el que se escanea
  # (que ya está acá) y dos más. El tipo de envío declarado es aéreo, distinto
  # del que Miami usó, a propósito.
  def grupo_de_tres(paquete)
    pa = PreAlerta.create!(numero_documento: "PA-T#{SecureRandom.hex(3).upcase}", cliente: clientes(:juan),
                           tipo_envio: tipo_envios(:aereo), consolidado: true, con_reempaque: true,
                           estado: "pre_alerta", titulo: "Consolidado de prueba",
                           creado_por_tipo: "usuario", creado_por_id: users(:admin).id)
    pa.pre_alerta_paquetes.create!(tracking: paquete.tracking, descripcion: "Zapatos", fecha: Date.current,
                                   paquete: paquete)
    otros = %w[1ZFALTA000000001 1ZFALTA000000002].map do |t|
      pa.pre_alerta_paquetes.create!(tracking: t, descripcion: "Gorra", fecha: Date.current).paquete
    end
    [ pa, otros ]
  end

  def llego(paquete)
    paquete.update!(estado: "recibido_miami", sucursal_recepcion: sucursales(:miami))
    paquete.update!(estado: "en_aduana")
    paquete.reload
  end

  # Un manifiesto oficial que salió de Miami, con esta caja y otras.
  def manifiesto_con(paquete, otras: 0)
    manifiesto = Manifiesto.create!(tipo_envios: [ tipo_envios(:cer) ],
                                    sucursal_origen: sucursales(:miami), estado: "recibido",
                                    fecha_enviado: Time.zone.parse("2026-08-20"),
                                    fecha_aduana: Time.zone.parse("2026-08-28"))
    paquete.update!(manifiesto: manifiesto)
    otras.times { |i| caja("1ZOTRA#{i}00000001").update!(manifiesto: manifiesto) }
    manifiesto
  end

  def hermana(madre, numero)
    Paquete.create!(tracking: madre.tracking, cliente: madre.cliente, tipo_envio: madre.tipo_envio,
                    sucursal_recepcion: sucursales(:miami), estado: madre.estado, descripcion: madre.descripcion,
                    peso: 2, numero_recepcion: madre.numero_recepcion,
                    cantidad_paquetes: madre.cantidad_paquetes, numero_caja: numero)
  end
end
