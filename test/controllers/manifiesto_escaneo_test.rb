require "test_helper"

# C28-04 · El escaneo del manifiesto dice **por qué** entra o no.
#
# Yusef, el 2026-10-03, viendo *«No se encontró ningún paquete libre»* sobre un
# paquete que ya estaba adentro: *"el mensaje está malo"*. Y lo que tenía que
# decir en cada caso:
#
#   > "Este paquete ya fue escaneado y está en este manifiesto… ya fue escaneado
#   >  y está en otro manifiesto… ¿desea agregar este a este manifiesto y
#   >  retirarlo del otro?"
#   > "El error es que diga que estás pagando CER y metas un paquete CKA… ahí
#   >  sí, porque genera gasto."
class ManifiestoEscaneoTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }
    @manifiesto = manifiestos(:creado)   # lleva CER por fixture
    @paquete = paquete("1ZESCANEO0000001")
  end

  test "un paquete libre del servicio del manifiesto: ok, y escanear no lo agrega solo" do
    escanear(@paquete.numero_recepcion)

    assert_equal "ok", json["resultado"]
    assert_equal @paquete.id, json.dig("paquete", "id")
    assert_match(/#{@paquete.numero_recepcion}.*agregado/, json["mensaje"])
    assert_nil @paquete.reload.manifiesto_id, "agregar es de add_paquete; escanear solo clasifica"
  end

  test "ya está en este manifiesto: lo dice con las palabras de Yusef" do
    @paquete.update!(manifiesto: @manifiesto)

    escanear(@paquete.numero_recepcion)

    assert_equal "en_este", json["resultado"]
    assert_match(/ya fue escaneado y está en este manifiesto/, json["mensaje"])
  end

  test "en otro manifiesto abierto: en_otro, nombrándolo" do
    otro = otro_manifiesto(estado: "creado")
    @paquete.update!(manifiesto: otro)

    escanear(@paquete.numero_recepcion)

    assert_equal "en_otro", json["resultado"]
    assert_equal otro.numero, json["otro_manifiesto"]
    assert_match(/está en el manifiesto #{otro.numero}/, json["mensaje"])
  end

  # Jorge, 2026-10-04: solo si el otro sigue abierto. Uno enviado ya viajó.
  test "en otro manifiesto que ya salió: no se ofrece mover" do
    otro = otro_manifiesto(estado: "enviado")
    @paquete.update!(manifiesto: otro)

    escanear(@paquete.numero_recepcion)

    assert_equal "en_otro_cerrado", json["resultado"]
    assert_match(/ya salió/, json["mensaje"])
  end

  test "de otro servicio: tipo_distinto, que es el error que genera gasto" do
    cem = paquete("1ZESCANEO0000002", tipo: tipo_envios(:cem))

    escanear(cem.numero_recepcion)

    assert_equal "tipo_distinto", json["resultado"]
    assert_match(/es #{tipo_envios(:cem).nombre}, y este manifiesto lleva/, json["mensaje"])
  end

  test "lo que no existe dice que no existe, no que no está libre" do
    escanear("NOEXISTE123456")

    assert_equal "no_encontrado", json["resultado"]
    assert_match(/No existe ningún paquete con «NOEXISTE123456»/, json["mensaje"])
    assert_no_match(/libre/, json["mensaje"])
  end

  # La etiqueta de la caja 2 tiene que caer en la caja 2, no en sus hermanas.
  test "el código con sufijo cae en su caja del split" do
    cajas = Paquete.crear_split!(attrs: atributos("1ZESCANEOSPLIT01"), total_cajas: 2)
    segunda = cajas.second

    escanear("#{segunda.numero_recepcion}-2")

    assert_equal "ok", json["resultado"]
    assert_equal segunda.id, json.dig("paquete", "id")
    assert_equal "#{segunda.numero_recepcion}-2", json.dig("paquete", "codigo")
  end

  # El tracking de un split trae las dos cajas: se elige, no se adivina. Y la
  # que ya está adentro no se ofrece.
  test "el tracking de un split ofrece elegir entre las cajas que faltan" do
    cajas = Paquete.crear_split!(attrs: atributos("1ZESCANEOSPLIT02"), total_cajas: 3)
    cajas.first.update!(manifiesto: @manifiesto)

    escanear("1ZESCANEOSPLIT02")

    assert_equal "varios", json["resultado"]
    assert_equal cajas.drop(1).map(&:id).sort, json["paquetes"].map { |p| p["id"] }.sort
  end

  test "elegir de la lista pasa por las mismas preguntas" do
    cem = paquete("1ZESCANEO0000003", tipo: tipo_envios(:cem))

    post escanear_manifiesto_url(@manifiesto), params: { paquete_id: cem.id }, as: :json

    assert_equal "tipo_distinto", json["resultado"]
  end

  # ── Mover ─────────────────────────────────────────────────────────────

  test "mover lo saca del otro abierto, suelta su caja y recalcula los dos" do
    otro = otro_manifiesto(estado: "creado")
    caja = otro.cajas.create!(alto: 10, largo: 10, ancho: 10, peso: 5)
    @paquete.update!(manifiesto: otro, caja_manifiesto: caja, estado: "empacado")
    otro.recalculate_totals!

    post mover_paquete_manifiesto_url(@manifiesto), params: { paquete_id: @paquete.id }, as: :turbo_stream

    assert_response :success
    @paquete.reload
    assert_equal @manifiesto, @paquete.manifiesto
    assert_nil @paquete.caja_manifiesto_id
    assert_equal "recibido_miami", @paquete.estado
    assert_equal 0, otro.reload.cantidad_paquetes
    assert_equal 1, @manifiesto.reload.cantidad_paquetes
  end

  test "mover no saca nada de un manifiesto que ya salió" do
    otro = otro_manifiesto(estado: "enviado")
    @paquete.update!(manifiesto: otro)

    post mover_paquete_manifiesto_url(@manifiesto), params: { paquete_id: @paquete.id }, as: :turbo_stream

    assert_equal otro, @paquete.reload.manifiesto
  end

  test "mover no mete un paquete de otro servicio" do
    otro = otro_manifiesto(estado: "creado", tipo: tipo_envios(:cem))
    cem = paquete("1ZESCANEO0000004", tipo: tipo_envios(:cem))
    cem.update!(manifiesto: otro)

    post mover_paquete_manifiesto_url(@manifiesto), params: { paquete_id: cem.id }, as: :turbo_stream

    assert_equal otro, cem.reload.manifiesto
  end

  private

  def escanear(codigo)
    post escanear_manifiesto_url(@manifiesto), params: { codigo: codigo }, as: :json
    assert_response :success
  end

  def json
    response.parsed_body
  end

  def atributos(tracking, tipo: tipo_envios(:cer))
    { tracking: tracking, cliente: clientes(:juan), tipo_envio: tipo,
      sucursal_recepcion: sucursales(:miami), sucursal: sucursales(:miami),
      estado: "recibido_miami", user: users(:digitador) }
  end

  def paquete(tracking, tipo: tipo_envios(:cer))
    Paquete.create!(atributos(tracking, tipo: tipo))
  end

  def otro_manifiesto(estado:, tipo: tipo_envios(:cer))
    Manifiesto.create!(numero: "MA-OTRO-#{SecureRandom.hex(3)}", estado: estado, user: users(:digitador),
                       tipo_envios: [ tipo ])
  end
end
