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
end
