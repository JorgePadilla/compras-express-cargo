require "test_helper"

# C27-01 · La pantalla del bulto, por JSON.
#
# Yusef, el 2026-09-07, tres veces en la misma reunión: *"no es una etiqueta por
# paquete, es una etiqueta por medición, y la medición puede tener 100
# paquetes"*. Y cómo se arma la medición, cuando Jorge le preguntó si se elegían
# de una lista: *"No, no, porque se van a equivocar. Eso es un error ya. No van
# a leer."* — *"¿Entonces cómo los unís?"* — **"Escaneando. Escaneando cada
# uno."**
#
# Así que lo que se prueba acá es el escaneo como puerta: qué entra a la mesa,
# qué rebota y con qué motivo, y qué sale al guardar la tanda.
class MedicionBultoTest < ActionDispatch::IntegrationTest
  setup do
    @medidor = users(:medidor)
    @medidor.update!(iniciales: "MD")
    ingresar(@medidor)
    @primera = caja("1ZBULTO000000001")
  end

  # ── El escaneo acumula ───────────────────────────────────────────────────

  test "cada escaneo agrega una caja a la mesa, y la mesa se manda de vuelta" do
    segunda = caja("1ZBULTO000000002")

    escanear(@primera.tracking)
    assert_equal "ok", json["resultado"]
    assert json["mesa"], "la caja entra a la mesa"
    assert_equal @primera.id, json["paquete"]["id"]

    escanear(segunda.tracking, en_tanda: [ @primera.id ])
    assert_equal "ok", json["resultado"]
    assert json["mesa"]
    assert_equal segunda.id, json["paquete"]["id"]
  end

  test "escanear dos veces la misma caja no la duplica: rebota por repetida" do
    escanear(@primera.tracking, en_tanda: [ @primera.id ])

    assert_equal "no_mezclar", json["resultado"]
    assert_equal "repetida", json["motivo"]
    assert_not json["mesa"], "una caja repetida no vuelve a entrar"
    assert_match(/ya está en la mesa/, json["mensaje"])
  end

  # El mismo warehouse impreso en las tres cajas de un split: se escanea tres
  # veces y entran las tres, una por pip.
  test "el mismo warehouse de un envío partido trae la caja siguiente, no la misma" do
    cajas = envio_partido(@primera, 3)
    wr = @primera.reload.numero_recepcion

    escanear(wr)
    assert_equal cajas[0].id, json["paquete"]["id"]

    escanear(wr, en_tanda: [ cajas[0].id ])
    assert_equal cajas[1].id, json["paquete"]["id"], "el segundo pip trae la caja 2, no otra vez la 1"

    escanear(wr, en_tanda: [ cajas[0].id, cajas[1].id ])
    assert_equal cajas[2].id, json["paquete"]["id"]
  end

  # ── «NO Mezclar» ─────────────────────────────────────────────────────────

  # Yusef: *"escanea uno de Jorge y va y escanea otro y ese no es el mismo Jorge
  # —en vez de Jorge Padilla es Jorge Manzano—: le tira error, es diferente
  # cliente"*.
  test "una caja de otro cliente rebota con su motivo, y no entra a la mesa" do
    otro = caja("1ZBULTO000000009", cliente: clientes(:maria))

    escanear(otro.tracking, en_tanda: [ @primera.id ])

    assert_equal "no_mezclar", json["resultado"]
    assert_equal "otro_cliente", json["motivo"]
    assert_not json["mesa"], "la caja rechazada nunca entra a la mesa"
    assert_match clientes(:maria).nombre_completo, json["mensaje"]
    assert_match clientes(:juan).nombre_completo, json["mensaje"]
  end

  test "otro servicio también rebota: cada servicio se factura aparte" do
    otro = caja("1ZBULTO000000010", tipo_envio: tipo_envios(:cem))

    escanear(otro.tracking, en_tanda: [ @primera.id ])

    assert_equal "otro_servicio", json["motivo"]
    assert_not json["mesa"]
    assert_match(/se factura aparte/i, json["mensaje"])
  end

  # Yusef: *"no lo podría hacer porque está consolidando esa carga con otros
  # paquetes… un modal que le diga: hey, no, ese está consolidando con tal
  # pre-alerta, con tal número. Ese va amarrado con otra."*
  test "una caja de otra consolidación dice con qué pre-alerta choca" do
    consolidada = caja("1ZBULTO000000011")
    pa = pre_alerta_consolidada(consolidada)

    escanear(consolidada.tracking, en_tanda: [ @primera.id ])

    assert_equal "otra_consolidacion", json["motivo"]
    assert_not json["mesa"]
    assert_equal pa.numero_documento, json["choque"]["numero"]
    assert_equal "Consolidado de prueba", json["choque"]["titulo"]
    assert_match pa.numero_documento, json["mensaje"]
  end

  # La otra dirección: la mesa ya trae un consolidado y entra una suelta.
  # Se facturan aparte —*"nosotros facturamos de acuerdo a la pre-alerta"*.
  test "una suelta contra un consolidado armado también rebota, y nombra la pre-alerta de la mesa" do
    consolidada = caja("1ZBULTO000000012")
    pa = pre_alerta_consolidada(consolidada)

    escanear(@primera.tracking, en_tanda: [ consolidada.id ])

    assert_equal "no_consolidada", json["motivo"]
    assert_equal pa.numero_documento, json["choque"]["numero"]
  end

  test "el modal del consolidado dice también a qué pre-factura pertenece, si ya tiene una" do
    consolidada = caja("1ZBULTO000000013")
    pa = pre_alerta_consolidada(consolidada)
    hermana = caja("1ZBULTO000000014")
    pa.pre_alerta_paquetes.create!(tracking: hermana.tracking, descripcion: "Gorra",
                                   fecha: Date.current, paquete: hermana)
    hermana.update!(pre_factura: pre_facturas(:borrador_juan))

    escanear(consolidada.tracking, en_tanda: [ @primera.id ])

    assert_equal "otra_consolidacion", json["motivo"]
    assert_equal pre_facturas(:borrador_juan).numero, json["choque"]["pre_factura"]
  end

  # ── Guardar la tanda ─────────────────────────────────────────────────────

  test "tres cajas en una medición son un bulto y una sola etiqueta" do
    cajas = [ @primera, caja("1ZBULTO000000003"), caja("1ZBULTO000000004") ]

    guardar([ { paquete_ids: cajas.map(&:id), peso: "20", alto: "10", largo: "12", ancho: "14" } ])

    assert_response :success
    assert_equal 1, json["cantidad"]
    assert_equal 1, Bulto.count
    assert_equal 3, Bulto.first.paquetes.count
    assert_match %r{/medicion/sesiones/.+/etiquetas\?print=true}, json["imprimir_url"]
    assert_nil json["bultos"].first["de_cuantos_texto"], "una medición sola no lleva «1 de 1»"
    assert_equal 3, json["bultos"].first["cajas"]
  end

  # Yusef: *"mide y pesa este, le da agregar; mide y pesa este por separado
  # porque no cuadra… y ahí le dice imprimir, y como son dos mediciones,
  # imprime dos"*.
  test "dos mediciones crean dos bultos, y las dos etiquetas dicen «1 de 2» y «2 de 2»" do
    otra = caja("1ZBULTO000000005")

    guardar([
      { paquete_ids: [ @primera.id ], peso: "20", alto: "10", largo: "12", ancho: "14" },
      { paquete_ids: [ otra.id ], peso: "8", alto: "5", largo: "6", ancho: "7" }
    ])

    assert_response :success
    assert_equal 2, json["cantidad"]
    assert_equal 2, Bulto.count
    assert_equal [ "1 de 2", "2 de 2" ], json["bultos"].map { |b| b["de_cuantos_texto"] }
    assert_equal 1, Bulto.pluck(:sesion).uniq.size, "las dos salieron de la misma mesa"

    get json["imprimir_url"]
    assert_response :success
    assert_equal 2, response.body.scan(/class="med"/).size, "dos mediciones, dos etiquetas"
  end

  # Lista blanca en la puerta: lo que venga de más en una medición se cae ahí,
  # no depende de que el modelo siga leyendo campo por campo.
  test "lo que no es peso ni medidas ni cajas no entra al bulto" do
    guardar([ { paquete_ids: [ @primera.id ], peso: "20",
                medido_por: "XX", sesion: "colada", cliente_id: clientes(:maria).id } ])

    assert_response :success
    bulto = Bulto.first
    assert_equal "MD", bulto.medido_por, "el sello es del que está adentro de la sesión"
    assert_equal clientes(:juan).id, bulto.cliente_id, "el cliente sale de la caja, no del request"
    assert_not_equal "colada", bulto.sesion
  end

  test "guardar sin números es 422 con el porqué, y no crea nada" do
    guardar([ { paquete_ids: [ @primera.id ], peso: "", alto: "", largo: "", ancho: "" } ])

    assert_response :unprocessable_entity
    assert_match(/al menos el peso/, json["errores"].first)
    assert_equal 0, Bulto.count
  end

  test "mezclar clientes en dos mediciones de la misma tanda es 422: la tanda es de uno solo" do
    otro = caja("1ZBULTO000000006", cliente: clientes(:maria))

    guardar([
      { paquete_ids: [ @primera.id ], peso: "20" },
      { paquete_ids: [ otro.id ], peso: "8" }
    ])

    assert_response :unprocessable_entity
    assert_equal 0, Bulto.count
  end

  test "más de diez mediciones en una tanda es 422" do
    mediciones = (Bulto::MAXIMO_POR_SESION + 1).times.map do |i|
      { paquete_ids: [ caja("1ZBULTOMAX#{format('%04d', i)}").id ], peso: "5" }
    end

    guardar(mediciones)

    assert_response :unprocessable_entity
    assert_match(/#{Bulto::MAXIMO_POR_SESION}/, json["errores"].first)
  end

  # ── Reimprimir ───────────────────────────────────────────────────────────

  # Yusef: *"él va a poder reimprimir la etiqueta, porque digamos que si se le
  # cae… ¿cómo la buscaría? **Tendría que volver a escanear el warehouse**"*.
  test "escanear una caja que ya tiene bulto ofrece reimprimir su etiqueta" do
    otra = caja("1ZBULTO000000007")
    guardar([ { paquete_ids: [ @primera.id, otra.id ], peso: "20", alto: "10", largo: "12", ancho: "14" } ])
    bulto = Bulto.first

    escanear(@primera.tracking)

    assert_equal "ya_tiene_bulto", json["resultado"]
    assert_not json["mesa"], "no vuelve a la mesa: ya está medida"
    assert_equal etiqueta_bulto_medicion_path(bulto, print: "true"), json["bulto"]["etiqueta_url"]
    assert_equal 2, json["bulto"]["cajas"]
    assert_match(/ya está medida/, json["mensaje"])

    get json["bulto"]["etiqueta_url"]
    assert_response :success
    assert_equal 1, response.body.scan(/class="med"/).size, "una etiqueta por medición, no una por caja"
  end

  test "la etiqueta del bulto lleva sus números y no los de la caja" do
    @primera.update!(peso: 3, alto: 5, largo: 6, ancho: 7)
    guardar([ { paquete_ids: [ @primera.id ], peso: "20", alto: "10", largo: "12", ancho: "14" } ])

    get etiqueta_bulto_medicion_path(Bulto.first)

    assert_response :success
    assert_match "20.00", response.body
    assert_match "10x12x14", response.body
    assert_no_match(/3\.00/, response.body)
    assert_match "1 caja", response.body
    assert_match "MD", response.body
  end

  # C27-06 · Un grupo consolidado medido en bultos imprime **una etiqueta por
  # bulto**, no una por caja: es la regla, y la ruta vieja del grupo sigue
  # siendo la que el JSON manda al facturar parcial.
  test "las etiquetas del grupo consolidado salen por bulto, no por caja" do
    segunda = caja("1ZBULTO000000015")
    pa = pre_alerta_consolidada(@primera, segunda)
    guardar([ { paquete_ids: [ @primera.id, segunda.id ], peso: "20", alto: "10", largo: "12", ancho: "14" } ])
    assert_response :success

    get etiquetas_grupo_medicion_path(pa)

    assert_response :success
    assert_equal 1, response.body.scan(/class="med"/).size,
                 "dos cajas medidas juntas son UNA etiqueta"
  end

  # ── C27-14 · Saltarse el manifiesto ──────────────────────────────────────
  #
  # Yusef: *"este tiene un bloqueo ahorita que me tiene loco: si no ha pasado el
  # proceso desde Miami para acá, no lo puede hacer. Y ya le dije que le tiene
  # que eliminar eso… **hay que poner una opción ahí**"*.

  test "una caja que no pasó por el manifiesto avisa, y dice que se puede medir igual" do
    suelta = caja("1ZBULTO000000020", estado: "enviado_honduras")

    escanear(suelta.tracking)

    assert_equal "no_esta_en_honduras", json["resultado"]
    assert json["puede_saltar"], "el aviso tiene que traer la puerta"
    assert_not json["mesa"]
    assert_match(/Se puede medir igual/, json["mensaje"])
  end

  test "con el permiso puesto, la misma caja entra a la mesa marcada" do
    suelta = caja("1ZBULTO000000021", estado: "enviado_honduras")

    post escanear_medicion_index_path,
         params: { codigo: suelta.tracking, en_tanda: [], saltar_manifiesto: true }, as: :json

    assert_equal "ok", json["resultado"]
    assert json["mesa"]
    assert json["salto_manifiesto"], "la mesa tiene que saber que esta caja va por excepción"
  end

  test "sin el permiso, guardarla es 422; con el permiso se guarda y queda sellada" do
    suelta = caja("1ZBULTO000000022", estado: "enviado_honduras")
    medicion = { paquete_ids: [ suelta.id ], peso: "20", alto: "10", largo: "12", ancho: "14" }

    guardar([ medicion ])
    assert_response :unprocessable_entity
    assert_equal 0, Bulto.count

    guardar([ medicion ], saltar: [ suelta.id ])

    assert_response :success
    assert_equal 1, Bulto.count
    suelta.reload
    assert_not_nil suelta.salto_manifiesto_at
    assert_equal "MD", suelta.salto_manifiesto_por
    assert_equal "enviado_honduras", suelta.salto_manifiesto_estado, "queda el estado que tenía"
    assert_equal "enviado_honduras", suelta.estado, "el estado del paquete **no** se toca"
  end

  test "una caja que sí pasó por el manifiesto no queda sellada aunque venga en la lista" do
    guardar([ { paquete_ids: [ @primera.id ], peso: "20" } ], saltar: [ @primera.id ])

    assert_response :success
    assert_nil @primera.reload.salto_manifiesto_at, "no hubo excepción que sellar"
  end

  # El otro portón sigue cerrado: ahí el peso se congeló y medirlo mentiría.
  test "«ya está en una pre-factura» sigue siendo un no rotundo, sin puerta" do
    @primera.update!(pre_factura: pre_facturas(:borrador_juan))

    escanear(@primera.tracking)
    assert_equal "en_pre_factura", json["resultado"]
    assert_not json["puede_saltar"]

    guardar([ { paquete_ids: [ @primera.id ], peso: "20" } ], saltar: [ @primera.id ])
    assert_response :unprocessable_entity
    assert_equal 0, Bulto.count
  end

  private

  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def json = JSON.parse(response.body)

  def escanear(codigo, en_tanda: [])
    post escanear_medicion_index_path, params: { codigo: codigo, en_tanda: en_tanda }, as: :json
  end

  def guardar(mediciones, saltar: [])
    post guardar_medicion_index_path,
         params: { mediciones: mediciones, saltar_manifiesto: saltar }, as: :json
  end

  def caja(tracking, cliente: clientes(:juan), tipo_envio: tipo_envios(:cer), estado: "en_aduana", **extra)
    Paquete.create!(tracking: tracking, cliente: cliente, tipo_envio: tipo_envio,
                    sucursal_recepcion: sucursales(:miami), estado: estado,
                    descripcion: "Zapatos", peso: 2, **extra)
  end

  def envio_partido(madre, n)
    madre.update!(cantidad_paquetes: n, numero_caja: 1)
    [ madre.reload, *(2..n).map { |i|
      Paquete.create!(tracking: madre.tracking, cliente: madre.cliente, tipo_envio: madre.tipo_envio,
                      sucursal_recepcion: sucursales(:miami), estado: madre.estado, descripcion: madre.descripcion,
                      peso: 2, numero_recepcion: madre.numero_recepcion, cantidad_paquetes: n, numero_caja: i)
    } ]
  end

  # La pre-alerta se arma con los paquetes **vinculados**: crear el renglón
  # solo con el tracking le fabrica un paquete «esperado» aparte, y entonces el
  # escaneo encuentra dos cajas con el mismo tracking y contesta «ambiguo».
  def pre_alerta_consolidada(*paquetes)
    pa = PreAlerta.create!(numero_documento: "PA-C#{SecureRandom.hex(3).upcase}", cliente: clientes(:juan),
                           tipo_envio: tipo_envios(:aereo), consolidado: true, estado: "pre_alerta",
                           titulo: "Consolidado de prueba", creado_por_tipo: "usuario",
                           creado_por_id: users(:admin).id)
    paquetes.each do |p|
      pa.pre_alerta_paquetes.create!(tracking: p.tracking, descripcion: "Bulto", fecha: Date.current, paquete: p)
    end
    pa
  end
end
