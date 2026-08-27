require "test_helper"

# PR-10.d: la etiqueta física (Dymo 2.25 × 1.25). Hasta ahora el sistema
# imprimía el Warehouse Receipt en hoja carta y se usaba como si fuera la
# etiqueta — Yusef: "aquí está tirando el warehouse, no la etiqueta".
class PaqueteEtiquetaTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:digitador).email_address,
                                password: "password123" }
    @paquete = paquetes(:recibido)
  end

  test "usa el layout de etiqueta, no el de carta" do
    get etiqueta_paquete_url(@paquete)

    assert_response :success
    assert_match "2.25in 1.25in", response.body, "debe declarar el tamaño Dymo"
    assert_no_match(/size: Letter/, response.body)
  end

  test "lleva codigo de barras del numero de recepcion" do
    get etiqueta_paquete_url(@paquete)

    assert_response :success
    assert_match "<svg", response.body, "el codigo de barras va en SVG inline"
  end

  test "muestra los campos que Yusef marco como necesarios" do
    get etiqueta_paquete_url(@paquete)
    body = response.body

    assert_match @paquete.cliente.codigo, body, "codigo de cliente completo"
    assert_match @paquete.cliente.nombre_completo.upcase, body.upcase
    assert_match @paquete.tracking, body
    assert_match "RETIRA EN", body, "la sucursal necesita encabezado (el 'San Pedro Soda')"
  end

  # C16-07 · Yusef, con las etiquetas de un retenido en la mano: "y sigue
  # saliendo el CER aquí. Mirá, sería así: retenido" · "el de retener me
  # dijiste RT, me va". Jorge: en lugar del servicio, las primeras tres letras
  # de RETENIDO. Salió RTE y Yusef lo corrigió al día siguiente (C18-01).
  test "un retenido en Miami imprime RET donde iba el servicio" do
    @paquete.update!(retener_miami: true, notas_retencion: "Caja abierta")

    get etiqueta_paquete_url(@paquete)

    servicio = response.body[/data-campo="tipo-envio"[^>]*>\s*([A-Z]{3})\s*</, 1]
    assert_equal "RET", servicio
    assert_no_match(/>\s*CER\s*</, response.body, "el servicio no puede salir al lado: RET lo reemplaza")
  end

  test "sin retencion sigue saliendo el servicio" do
    @paquete.update!(tipo_envio: tipo_envios(:cer))
    assert_not @paquete.retener_miami?

    get etiqueta_paquete_url(@paquete)

    servicio = response.body[/data-campo="tipo-envio"[^>]*>\s*([A-Z]{3})\s*</, 1]
    assert_equal "CER", servicio
  end

  test "con hermanas=1 todas las cajas del retenido dicen RET" do
    cajas = Paquete.crear_split!(
      attrs: { tracking: "1ZRTEHERMANAS001", cliente: @paquete.cliente, tipo_envio: tipo_envios(:cer),
               descripcion: "Dos cajas retenidas", estado: "recibido_miami", user: users(:digitador),
               sucursal_recepcion: sucursales(:miami), retener_miami: true, notas_retencion: "Mojado" },
      total_cajas: 2
    )

    get etiqueta_paquete_url(cajas.first, hermanas: 1)

    servicios = response.body.scan(/data-campo="tipo-envio"[^>]*>\s*([A-Z]{3})\s*</).flatten
    assert_equal %w[RET RET], servicios
  end

  test "no lleva terminos y condiciones ni precios" do
    get etiqueta_paquete_url(@paquete)

    assert_no_match(/Terms &amp; Conditions/, response.body)
    assert_no_match(/Declared Value/, response.body)
  end

  test "con hermanas=1 imprime una etiqueta por caja" do
    tracking = "1Z999SPLITETQ"
    3.times do |i|
      Paquete.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                      tracking: tracking, numero_caja: i + 1, cantidad_paquetes: 3,
                      descripcion: "Caja #{i + 1}", user: users(:digitador))
    end
    p1 = Paquete.find_by(tracking: tracking, numero_caja: 1)

    get etiqueta_paquete_url(p1, hermanas: "1")

    assert_response :success
    # "si el tracking se divide en 5 paquetes es una para cada una"
    assert_equal 3, response.body.scan(/class="etq"/).size
    # `A7-21` decía que la etiqueta llevara el número solo, y su razón era del
    # **empaque**: *"no estamos seguros cuántas estamos empacando"*.
    #
    # Al recibir es al revés: la cantidad se fija antes de imprimir —el operario
    # cargó las cajas o contestó cuántas—, y por eso el código de barras ya salía
    # con su sufijo. Jorge, con una etiqueta de dos cajas en la mano: *"el 1 está
    # bien, pero aquí yo mandé 2; cuando manda más de una debe llevar el 1/2"*.
    #
    # La fracción sale **solo cuando el total está grabado**; ver
    # `test/helpers/etiqueta_fraccion_test.rb`.
    assert_match ">1/3</span>", response.body
    assert_match ">3/3</span>", response.body
  end

  test "sin hermanas imprime solo la del paquete" do
    get etiqueta_paquete_url(@paquete)

    assert_equal 1, response.body.scan(/class="etq"/).size
  end

  test "el warehouse receipt sigue existiendo aparte" do
    get warehouse_receipt_paquete_url(@paquete)

    assert_response :success
    assert_match "WAREHOUSE RECEIPT", response.body
    assert_match(/T.RMINOS|TERMS/i, response.body,
                 "el WR lleva terminos y condiciones — es el documento del expediente")
  end

  # ── PR-10.d.3: los caminos que decían "etiqueta" e imprimían el WR ──
  #
  # Yusef lo reportó una vez —"aquí está tirando el warehouse, no la etiqueta"—
  # y se arregló solo en /etiquetar. Todos los demás caminos siguieron sacando
  # la hoja carta, incluido el botón que se llama "Re-imprimir Etiquetas Miami".

  test "el icono de imprimir del listado saca la etiqueta, no el warehouse" do
    get paquetes_url

    assert_response :success
    assert_match etiqueta_paquete_path(@paquete), response.body
  end

  test "reimprimir de un paquete sin dividir lleva a la etiqueta" do
    assert_not @paquete.dividido?

    get reimprimir_etiquetas_paquete_url(@paquete)

    assert_redirected_to etiqueta_paquete_path(@paquete)
  end

  test "las etiquetas combinadas son etiquetas, no warehouse receipts" do
    hermanas = crear_hermanas(3)

    get etiquetas_combinadas_paquetes_url(paquete_ids: hermanas.map(&:id))

    assert_response :success
    assert_equal 3, response.body.scan(/class="etq"/).size
    assert_no_match(/WAREHOUSE RECEIPT/, response.body,
                    "esta pantalla se llama re-imprimir ETIQUETAS")
  end

  test "ningun flujo de etiqueta imprime el warehouse receipt" do
    # Un solo guard para los cuatro caminos: si alguno vuelve a apuntar al
    # documento equivocado, se cae acá.
    hermanas = crear_hermanas(2)

    urls = [
      etiqueta_paquete_url(@paquete),
      etiquetas_combinadas_paquetes_url(paquete_ids: hermanas.map(&:id))
    ]

    urls.each do |url|
      get url
      assert_no_match(/WAREHOUSE RECEIPT/, response.body, "#{url} imprime el documento equivocado")
    end
  end

  private

  def crear_hermanas(n)
    (1..n).map do |i|
      Paquete.create!(
        tracking: @paquete.tracking, guia: "COMB-#{i}-#{SecureRandom.hex(3)}",
        cliente: @paquete.cliente, tipo_envio: @paquete.tipo_envio,
        estado: @paquete.estado, peso: 5, peso_cobrar: 5,
        cantidad_productos: 1, cantidad_paquetes: n, numero_caja: i,
        descripcion: "Caja #{i}", user: users(:digitador)
      )
    end
  end
end
