require "test_helper"

# C21-07 · Recibir la carga en Honduras — «la pantallita» y «el aparatito».
#
# Cierra el hueco más grande que tenía el sistema: `lib/procesos_pdf.rb` marcaba
# el paso de Aduana con `existe: false` y la frase *"hoy se cambia el estado a
# mano"*, y `en_aduana` no tenía **ni un solo escritor** en todo el código — el
# único camino era el dropdown de la ficha del paquete, uno por uno.
#
#   > **Jorge:** "¿En el sistema qué perfil es el que hace eso?"
#   > **Yusef:** "**Los de prefactura**, ellos son los que se encargan de
#   >  recibir carga."
#   > "Quiero **el aparatito**: que vengan ellos, llegan a recibir carga, y
#   >  **escanean la caja** y automáticamente el sistema lo [pone]."
class RecepcionCargaTest < ActionDispatch::IntegrationTest
  setup do
    Current.session = Struct.new(:user).new(users(:cajero))
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }

    @manifiesto = manifiestos(:creado)
    @paquete = crear_paquete
    @caja = @manifiesto.cajas.create!(alto: 46, largo: 43, ancho: 50, peso: 131)
    @paquete.update!(caja_manifiesto: @caja)
    @manifiesto.finalizar!(user: users(:digitador))
  end

  teardown { Current.session = nil }

  # *"Es mejor una pantallita que ahí buscara y que solo le aparezca lo que
  # tiene que meter… solo lo que está como enviado."*
  test "solo aparecen los manifiestos que vienen en camino" do
    otro = Manifiesto.create!(tipo_envios: [ tipo_envios(:cer) ])   # sigue en creado

    get recepcion_carga_index_path

    assert_response :success
    assert_includes response.body, @manifiesto.numero
    assert_not_includes response.body, otro.numero,
                        "un manifiesto que Miami todavía no finalizó no se recibe"
  end

  # *"Escanearon cada caja, cada etiqueta de manifiesto. No escanean los
  # paquetes, solo escanean las cajas"* (`A7-06`).
  test "se escanean cajas, y sus paquetes pasan a aduana" do
    escanear(@caja.codigo)

    assert_equal "ok", json["resultado"]
    assert @caja.reload.recibida_at.present?
    assert_equal users(:cajero), @caja.recibida_por
    assert_equal "en_aduana", @paquete.reload.estado
    assert @paquete.fecha_aduana.present?, "el estado trae su fecha"
  end

  test "el código de un paquete no sirve: se escanean cajas" do
    escanear(@paquete.numero_recepcion)

    assert_equal "no_es_de_aqui", json["resultado"]
  end

  test "una caja de otro manifiesto no entra acá" do
    otro = Manifiesto.create!(tipo_envios: [ tipo_envios(:cer) ])
    ajena = otro.cajas.create!(peso: 5)

    escanear(ajena.codigo)

    assert_equal "no_es_de_aqui", json["resultado"]
  end

  test "escanear dos veces la misma caja avisa, no duplica" do
    escanear(@caja.codigo)
    escanear(@caja.codigo)

    assert_equal "ya_recibida", json["resultado"]
  end

  test "completar el manifiesto lo deja recibido" do
    escanear(@caja.codigo)

    patch finalizar_recepcion_carga_path(@manifiesto)

    assert_equal "recibido", @manifiesto.reload.estado
    assert @manifiesto.recepcion_finalizada_at.present?
  end

  # `A7-05` · Jorge preguntó qué tan dura era la regla —*"puede llegar a
  # convertirse en un problema en el proceso"*— y Yusef eligió *"que no lo
  # bloquee"*: avisa con el faltante enumerado y ofrece las dos salidas.
  test "si falta una caja no bloquea: avisa cuál falta" do
    falta = @manifiesto.cajas.create!(peso: 19)
    escanear(@caja.codigo)

    patch finalizar_recepcion_carga_path(@manifiesto)

    assert_redirected_to recepcion_carga_path(@manifiesto)
    assert_match(/Faltan 1 de 2/, flash[:alert])
    assert_match(/#{falta.letra}/, flash[:alert])
    assert_equal "en_aduana", @manifiesto.reload.estado, "sigue abierto para seguir escaneando"
  end

  test "marcar recibido con las pendientes cierra igual y manda correo" do
    faltante = @manifiesto.cajas.create!(peso: 19)
    suelto = crear_paquete
    suelto.update!(caja_manifiesto: faltante, estado: "enviado_honduras")
    escanear(@caja.codigo)

    assert_enqueued_emails 1 do
      patch finalizar_recepcion_carga_path(@manifiesto, con_faltantes: true)
    end

    assert_equal "recibido", @manifiesto.reload.estado
    assert_equal "en_aduana", suelto.reload.estado,
                 "los paquetes de la caja que faltó pasan igual: no se traba la operación"
  end

  test "quien no es de pre-factura no recibe carga" do
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }

    get recepcion_carga_index_path

    assert_redirected_to root_path
  end

  private

  def escanear(codigo)
    post escanear_recepcion_carga_path(@manifiesto), params: { codigo: codigo }, as: :json
  end

  def crear_paquete
    Paquete.create!(
      tracking: "1ZREC#{SecureRandom.hex(5).upcase}", cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
      sucursal_recepcion: sucursales(:miami), estado: "recibido_miami",
      descripcion: "Perfumes", user: users(:digitador), manifiesto: @manifiesto
    )
  end

  def json = JSON.parse(response.body)
  # ── El camino sin escaneo (C21-01) ──────────────────────────────────────
  #
  # Yusef dejó **dos caminos vivos** a propósito: el nuevo —crear el manifiesto,
  # sacar las pre-etiquetas de los bultos y escanear cada paquete adentro— y el
  # de siempre, *"que es lo que está actualmente"*, que se queda *"porque a
  # veces no da tiempo"*: se le meten los paquetes al manifiesto derecho, sin
  # cajas y sin pistola.
  #
  # Jorge lo notó leyendo el flujograma (2026-08-30): *"manifiesto tiene dos
  # flujos, con pre-manifiesto y sin pre-manifiesto, no veo esa lógica"*. Y al
  # mirarlo apareció que el segundo **estaba roto de punta a punta**: la
  # recepción solo movía `caja.paquetes`, así que un manifiesto sin cajas
  # cerraba bien y sus paquetes se quedaban en `enviado_honduras` para siempre.
  test "un manifiesto sin cajas manda igual sus paquetes a aduana" do
    manifiesto = manifiestos(:enviado)
    suelto = crear_paquete_suelto(manifiesto)

    patch finalizar_recepcion_carga_url(manifiesto)

    assert_equal "en_aduana", suelto.reload.estado
    assert_equal "recibido", manifiesto.reload.estado
  end

  # Y de ahí sigue el recorrido: si no llegan a aduana, tampoco llegan a la
  # pre-factura, porque `Paquete.facturables` arranca en `en_aduana`.
  test "y de ahí siguen a la pre-factura" do
    manifiesto = manifiestos(:enviado)
    suelto = crear_paquete_suelto(manifiesto)

    patch finalizar_recepcion_carga_url(manifiesto)

    assert_includes Paquete.facturables, suelto.reload
  end

  # La pantalla no puede decir «0 de 0 recibidas» sobre un manifiesto con carga.
  test "la pantalla avisa de los paquetes sin caja" do
    manifiesto = manifiestos(:enviado)
    crear_paquete_suelto(manifiesto)

    get recepcion_carga_url(manifiesto)

    assert_response :success
    assert_match(/sin caja/, response.body)
  end

  # Con cajas Y sueltos —un manifiesto que se empezó a escanear y se terminó a
  # mano— tienen que salir los dos.
  test "con cajas y sueltos, pasan los dos" do
    manifiesto = manifiestos(:enviado)
    suelto = crear_paquete_suelto(manifiesto)
    caja = manifiesto.cajas.create!(alto: 10, largo: 10, ancho: 10, peso: 5)
    en_caja = crear_paquete_suelto(manifiesto)
    en_caja.update!(caja_manifiesto: caja)

    post escanear_recepcion_carga_url(manifiesto), params: { codigo: caja.codigo }, as: :json
    patch finalizar_recepcion_carga_url(manifiesto)

    assert_equal "en_aduana", en_caja.reload.estado, "el escaneado"
    assert_equal "en_aduana", suelto.reload.estado, "y el suelto"
  end

  private

  def crear_paquete_suelto(manifiesto)
    Paquete.create!(
      tracking: "SINCAJA#{SecureRandom.hex(4).upcase}",
      cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
      sucursal_recepcion: sucursales(:miami),
      estado: "enviado_honduras", manifiesto: manifiesto
    )
  end

  # ── C23-14 · Dónde quedó la carga ────────────────────────────────────────
  #
  # `paquetes.sucursal_actual` dice, por su propia declaración, la *"ubicación
  # física actual"*. La escribía **un solo lugar en todo el sistema**: la
  # recepción del manifiesto **interno**.
  #
  # O sea que la carga que entra de Miami —por donde entra **toda** la que llega
  # al país— pasaba a `en_aduana` sin dejar dicho en qué sucursal aterrizó. La
  # columna quedaba en nil justo para el 100% del inventario, y solo se llenaba
  # si esa carga después viajaba en un interno: para saber dónde estaba algo
  # había que haberlo movido antes.
  #
  # Se destapó buscando cómo armar «empacar sin escanear» para el interno
  # (`C23-10`), que necesita preguntar *"qué hay parado en esta sucursal"*.

  test "C23-14 · recibir una caja deja dicho en qué sucursal quedó la carga" do
    manifiesto = manifiestos(:enviado)
    manifiesto.update!(sucursal_entrega: sucursales(:zeron_sps))
    caja = manifiesto.cajas.create!(alto: 10, largo: 10, ancho: 10, peso: 5)
    paquete = manifiesto.paquetes.first || paquetes(:disponible_entrega_juan)
    paquete.update!(manifiesto: manifiesto, caja_manifiesto: caja,
                    estado: "enviado_honduras", sucursal_actual: nil)

    RecibirManifiesto.new(manifiesto, user: users(:digitador)).recibir_caja!(caja)

    assert_equal "en_aduana", paquete.reload.estado
    assert_equal sucursales(:zeron_sps), paquete.sucursal_actual,
                 "sin esto no se puede preguntar qué hay parado en una sucursal"
  end

  # El camino **sin escaneo** llega por otra puerta y tiene que sellar igual: es
  # el que Yusef se quedó *"porque a veces no da tiempo"*, y es justamente el que
  # llega sin cajas.
  test "C23-14 · el camino sin escaneo también deja dicho dónde quedó" do
    manifiesto = manifiestos(:enviado)
    manifiesto.update!(sucursal_entrega: sucursales(:zeron_sps))
    paquete = paquetes(:disponible_entrega_juan)
    paquete.update!(manifiesto: manifiesto, caja_manifiesto: nil,
                    estado: "enviado_honduras", sucursal_actual: nil)

    RecibirManifiesto.new(manifiesto, user: users(:digitador)).finalizar!(con_faltantes: true)

    assert_equal sucursales(:zeron_sps), paquete.reload.sucursal_actual
  end

  # Sin sucursal de entrega no se inventa ninguna: es mejor no saber dónde está
  # que decir que está donde no está.
  test "C23-14 · sin sucursal de entrega no le inventa una" do
    manifiesto = manifiestos(:enviado)
    manifiesto.update!(sucursal_entrega: nil)
    paquete = paquetes(:disponible_entrega_juan)
    paquete.update!(manifiesto: manifiesto, caja_manifiesto: nil,
                    estado: "enviado_honduras", sucursal_actual: nil)

    RecibirManifiesto.new(manifiesto, user: users(:digitador)).finalizar!(con_faltantes: true)

    assert_nil paquete.reload.sucursal_actual
  end
end
