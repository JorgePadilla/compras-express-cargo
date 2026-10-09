require "test_helper"

# C30-09 · La pistola de la lista de /recibir-carga: cualquier caja de cualquier
# manifiesto pendiente, sin elegirlo antes.
#
#   > **Yusef:** "A veces vamos a recibir tres manifiestos de un solo y hay que
#   >  estar seleccionando cada manifiesto, entonces solo crear un search…"
#   > **Jorge:** "Vamos a implementar un search para que escanea ahí… todos
#   >  los pendientes."
#   > **Yusef:** "Si la vuelve a repetir una, solo que avise que ella ya fue
#   >  recibida."
#
# Y el botón de imprimir en la fila: *"acá afuera sería bueno poder darle
# también imprimir al manifiesto… lo voy a querer imprimir para darle al
# oficio"*.
class RecepcionCargaVariosManifiestosTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }

    @uno = enviado("MRCV000001")
    @dos = enviado("MRCV000002")
    @a1 = caja_con_paquete(@uno)
    @b1 = caja_con_paquete(@uno)
    @a2 = caja_con_paquete(@dos)
  end

  def enviado(numero, **extra)
    Manifiesto.create!({ numero: numero, estado: "enviado", tipo_envio: "AEREO", fecha_enviado: 1.day.ago,
                         sucursal_origen: sucursales(:miami), sucursal_entrega: sucursales(:zeron_sps),
                         user: users(:admin), tipo_envios: [ tipo_envios(:cer) ] }.merge(extra))
  end

  def caja_con_paquete(manifiesto)
    caja = manifiesto.cajas.create!(peso: 10)
    paquete(manifiesto, caja_manifiesto: caja)
    caja
  end

  def paquete(manifiesto, **extra)
    Paquete.create!({ tracking: "1ZRCV#{SecureRandom.hex(5).upcase}", cliente: clientes(:juan),
                      tipo_envio: tipo_envios(:cer), sucursal_recepcion: sucursales(:miami),
                      estado: "enviado_honduras", descripcion: "Ropa", manifiesto: manifiesto }.merge(extra))
  end

  def escanear(codigo)
    post escanear_pendientes_recepcion_carga_index_path, params: { codigo: codigo }, as: :json
  end

  def json = response.parsed_body

  # ── La pistola de la lista ──────────────────────────────────────────────

  test "cada caja entra en su manifiesto, sin elegirlo" do
    escanear(@b1.codigo)
    assert_equal "ok", json["resultado"]
    assert_equal "MRCV000001", json.dig("manifiesto", "numero")

    escanear(@a2.codigo)
    assert_equal "ok", json["resultado"]
    assert_equal "MRCV000002", json.dig("manifiesto", "numero")

    assert @b1.reload.recibida_at.present?
    assert @a2.reload.recibida_at.present?
    assert_nil @a1.reload.recibida_at, "la otra caja del primero no se tocó"
  end

  # Mismas reglas y efectos que la pistola de adentro: es el mismo camino.
  test "los paquetes de la caja pasan a aduana y queda quién la recibió" do
    escanear(@a2.codigo)

    assert_equal users(:cajero), @a2.reload.recibida_por
    paquete = @a2.paquetes.first
    assert_equal "en_aduana", paquete.estado
    assert_equal sucursales(:zeron_sps), paquete.sucursal_actual
    assert_equal "en_aduana", @dos.reload.estado
  end

  test "dice cuánto va y qué falta de ese manifiesto" do
    escanear(@a1.codigo)

    assert_equal 1, json.dig("manifiesto", "recibidas")
    assert_equal 2, json.dig("manifiesto", "total")
    assert_equal [ @b1.letra ], json.dig("manifiesto", "faltantes")
    assert_equal "1 de 2 · falta 1", json.dig("manifiesto", "texto")
    assert_equal false, json.dig("manifiesto", "completo")
  end

  test "la que completa el manifiesto lo dice, pero no lo cierra" do
    escanear(@a1.codigo)
    escanear(@b1.codigo)

    assert_equal true, json.dig("manifiesto", "completo")
    assert_equal "2 de 2 · completo", json.dig("manifiesto", "texto")
    assert_equal "en_aduana", @uno.reload.estado,
                 "«Terminar» sigue siendo un acto aparte: cerrar con faltantes manda correo"
  end

  test "si la vuelve a repetir, avisa que ya fue recibida y de qué manifiesto" do
    escanear(@a2.codigo)
    escanear(@a2.codigo)

    assert_equal "ya_recibida", json["resultado"]
    assert_match(/ya estaba recibida/, json["mensaje"])
    assert_match(/MRCV000002/, json["mensaje"])
  end

  test "la caja de un manifiesto ya cerrado también avisa que ya fue recibida" do
    escanear(@a2.codigo)
    patch finalizar_recepcion_carga_path(@dos)
    assert_equal "recibido", @dos.reload.estado

    escanear(@a2.codigo)

    assert_equal "ya_recibida", json["resultado"]
    assert_match(/ya se cerró/, json["mensaje"])
  end

  test "una caja de un manifiesto que Miami no finalizó no se recibe" do
    creado = Manifiesto.create!(tipo_envios: [ tipo_envios(:cer) ])
    caja = creado.cajas.create!(peso: 3)

    escanear(caja.codigo)

    assert_equal "no_es_de_aqui", json["resultado"]
    assert_match(/todavía no finalizó/, json["mensaje"])
    assert_nil caja.reload.recibida_at
  end

  test "lo que no es de ningún pendiente se rechaza" do
    escanear("CUALQUIERCOSA")

    assert_equal "no_es_de_aqui", json["resultado"]
    assert_match(/ningún manifiesto pendiente/, json["mensaje"])
  end

  test "el paquete suelto de un oficial no se recibe: se escanean cajas" do
    suelto = @a1.paquetes.first

    escanear(suelto.tracking)

    assert_equal "no_es_de_aqui", json["resultado"]
    assert_match(/Se escanean las cajas/, json["mensaje"])
    assert_equal "enviado_honduras", suelto.reload.estado
  end

  # `A7-08` · El interno está en la misma lista, y su unidad es el paquete.
  test "el paquete de un interno pendiente se recibe en su sucursal" do
    interno = enviado("MRCV000009", tipo: "interno", sucursal_entrega: sucursales(:humuya_tgu))
    p = paquete(interno, estado: "enviado_sucursal", sucursal_destino: sucursales(:humuya_tgu))

    escanear(p.tracking)

    assert_equal "ok", json["resultado"]
    assert_equal "MRCV000009", json.dig("manifiesto", "numero")
    assert_equal "disponible_entrega", p.reload.estado
    assert_equal sucursales(:humuya_tgu), p.sucursal_actual
  end

  test "quien no es de pre-factura no escanea" do
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }

    escanear(@a1.codigo)

    assert_redirected_to root_path
    assert_nil @a1.reload.recibida_at
  end

  # ── La pistola de adentro sigue igual, y ahora también cuenta ───────────

  test "la pistola del manifiesto devuelve el mismo progreso" do
    post escanear_recepcion_carga_path(@uno), params: { codigo: @a1.codigo }, as: :json

    assert_equal "ok", json["resultado"]
    assert_equal 1, json["faltan"]
    assert_equal "1 de 2 · falta 1", json.dig("manifiesto", "texto")
  end

  test "la pistola del manifiesto sigue rechazando cajas de otro" do
    post escanear_recepcion_carga_path(@uno), params: { codigo: @a2.codigo }, as: :json

    assert_equal "no_es_de_aqui", json["resultado"]
    assert_nil @a2.reload.recibida_at
  end

  # ── La lista ────────────────────────────────────────────────────────────

  test "la lista trae la pistola y, por fila, lo que va y lo que falta" do
    RecibirManifiesto.new(@uno).recibir_caja!(@a1)

    get recepcion_carga_index_path

    assert_select "input#codigo_caja[data-action*='keydown->recepcion-carga#teclado']"
    assert_select "[data-manifiesto-fila='#{@uno.id}'] [data-progreso-texto]", text: "1 de 2 · falta 1"
    assert_select "[data-manifiesto-fila='#{@uno.id}'] [data-progreso-faltan]", text: "Falta: #{@b1.letra}"
  end

  # ── Terminar desde la fila ──────────────────────────────────────────────
  #
  # Con cinco manifiestos de un solo, entrar a cada uno solo para cerrarlo era
  # un viaje de más. Es el mismo `finalizar`, sin `con_faltantes`.

  test "cada fila trae su «Terminar», que es el finalizar de adentro" do
    get recepcion_carga_index_path

    assert_select "[data-manifiesto-fila='#{@uno.id}'] form[action='#{finalizar_recepcion_carga_path(@uno)}']" do
      assert_select "input[name='_method'][value='patch']"
      assert_select "button", text: /Terminar/
    end
    assert_select "[data-manifiesto-fila] form[action*='con_faltantes']", { count: 0 },
                  "cerrar con pendientes no se aprieta desde una fila"
  end

  test "terminar desde la lista con todo recibido cierra y vuelve a la lista" do
    escanear(@a2.codigo)

    patch finalizar_recepcion_carga_path(@dos)

    assert_redirected_to recepcion_carga_index_path
    assert_equal "recibido", @dos.reload.estado
    follow_redirect!
    assert_select "[data-manifiesto-fila='#{@dos.id}']", { count: 0 }, "ya no es pendiente"
    assert_select "[data-manifiesto-fila='#{@uno.id}']"
  end

  # `A7-05` · Si falta algo no cierra: lleva al manifiesto con lo que falta y
  # las dos salidas. El correo sale solo de «marcar recibido con las
  # pendientes», que está allá y pide confirmación.
  test "terminar desde la lista con cajas faltantes no cierra ni manda correo" do
    escanear(@a1.codigo)

    assert_no_enqueued_emails do
      patch finalizar_recepcion_carga_path(@uno)
    end

    assert_redirected_to recepcion_carga_path(@uno)
    assert_match(/Faltan 1 de 2: caja\(s\) #{@b1.letra}/, flash[:alert])
    assert_equal "en_aduana", @uno.reload.estado
  end

  # ── Imprimir desde la fila ──────────────────────────────────────────────

  test "cada fila imprime la hoja de su manifiesto, y se cierra al imprimir" do
    get recepcion_carga_index_path

    href = documento_recepcion_carga_path(@uno, print: true, cerrar: 1)
    assert_select "[data-manifiesto-fila='#{@uno.id}'] a[href='#{href}'][target='_blank']", text: /Imprimir/
  end

  test "quien recibe carga imprime la hoja, aunque no entre a /manifiestos" do
    get documento_recepcion_carga_path(@uno)

    assert_response :success
    assert_match "Manifiesto MRCV000001", response.body
    assert_match @a1.codigo, response.body

    get documento_manifiesto_path(@uno)
    assert_redirected_to root_path, "la sección de manifiestos sigue siendo de Miami"
  end

  # La lista trae internos también, y cada fila tiene su «Imprimir».
  test "la hoja de un interno también se imprime" do
    interno = enviado("MRCV000010", tipo: "interno", sucursal_entrega: sucursales(:humuya_tgu))

    get documento_recepcion_carga_path(interno)

    assert_response :success
    assert_match "MRCV000010", response.body
  end
end
