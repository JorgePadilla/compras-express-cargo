require "test_helper"

# C21-01 · El escaneo al empacar — el «pip pip pip».
#
# Yusef, mostrando la bodega en vivo por cámara mientras empacaban:
#
#   > "Ahí están empacando, mirá… y aquí es donde hace falta, **es el pip pip
#   >  pip**."
#
# Y la pregunta que abrió el módulo entero: *"¿qué otra forma puedo hacer para
# empezar a decir que **estos paquetes van en esa caja**?"*
class EmpaqueControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }
    @manifiesto = manifiestos(:creado)   # lleva CER por fixture
    @caja = @manifiesto.cajas.create!(alto: 46, largo: 43, ancho: 50, peso: 131)
    @paquete = Paquete.create!(
      tracking: "1ZEMPAQUE0000001", cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
      sucursal_recepcion: sucursales(:miami), estado: "recibido_miami",
      descripcion: "Perfumes", user: users(:digitador)
    )
  end

  test "la pantalla abre con las cajas del manifiesto" do
    get manifiesto_empacar_path(@manifiesto)

    assert_response :success
    assert_includes response.body, @caja.codigo
  end

  # Es el primer lugar del sistema que escribe `empacado`. Vivía en el enum sin
  # dueño: `EtiquetarController` lo dejó reservado con nombre y apellido.
  test "escanear un paquete lo mete a la caja y lo deja empacado" do
    escanear(@paquete.numero_recepcion)

    assert_equal "ok", json["resultado"]
    @paquete.reload
    assert_equal @caja, @paquete.caja_manifiesto
    assert_equal @manifiesto, @paquete.manifiesto, "la caja arrastra el manifiesto"
    assert_equal "empacado", @paquete.estado
    assert @paquete.fecha_empacado.present?, "el estado trae su fecha"
  end

  test "los totales del manifiesto se actualizan al empacar" do
    escanear(@paquete.numero_recepcion)

    assert_equal 1, @manifiesto.reload.cantidad_paquetes
  end

  # *"Si el tipo de servicio no concuerda con el de la caja, pita."*
  test "un paquete de otro tipo de envío no entra, y el sistema avisa" do
    otro = Paquete.create!(
      tracking: "1ZEMPAQUE0000002", cliente: clientes(:juan), tipo_envio: tipo_envios(:cem),
      sucursal_recepcion: sucursales(:miami), estado: "recibido_miami",
      descripcion: "Perfumes", user: users(:digitador)
    )

    escanear(otro.numero_recepcion)

    assert_equal "tipo_distinto", json["resultado"]
    assert_nil otro.reload.caja_manifiesto, "no puede entrar por la fuerza"
    assert_equal "recibido_miami", otro.estado
  end

  # *"Botón de omitir para no trabar la operación cuando algo no cuadra."*
  test "omitir lo mete igual, sin trabar la operación" do
    otro = Paquete.create!(
      tracking: "1ZEMPAQUE0000003", cliente: clientes(:juan), tipo_envio: tipo_envios(:cem),
      sucursal_recepcion: sucursales(:miami), estado: "recibido_miami",
      descripcion: "Perfumes", user: users(:digitador)
    )

    post manifiesto_omitir_empaque_path(@manifiesto, @caja),
         params: { paquete_id: otro.id }, as: :json

    assert_equal "ok", json["resultado"]
    assert_equal @caja, otro.reload.caja_manifiesto
  end

  test "un código que no existe avisa y no rompe" do
    escanear("NOEXISTE123456")

    assert_equal "no_encontrado", json["resultado"]
  end

  test "un paquete que ya está en otra caja avisa cuál" do
    otra = @manifiesto.cajas.create!(peso: 10)
    @paquete.update!(caja_manifiesto: otra, manifiesto: @manifiesto)

    escanear(@paquete.numero_recepcion)

    assert_equal "ya_empacado", json["resultado"]
    assert_includes json["mensaje"], otra.letra
  end

  # El operario escanea la ETIQUETA del paquete, y ese código es el número de
  # recepción con su sufijo de caja — no el tracking.
  test "se escanea el número de recepción, con o sin sufijo de caja" do
    escanear("#{@paquete.numero_recepcion}-1")

    assert_equal "ok", json["resultado"]
  end

  test "y el tracking también sirve, por si escanean la del courier" do
    escanear(@paquete.tracking)

    assert_equal "ok", json["resultado"]
  end

  test "quien no es de Miami no empaca" do
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }

    get manifiesto_empacar_path(@manifiesto)

    assert_redirected_to root_path
  end

  private

  def escanear(codigo)
    post manifiesto_escanear_empaque_path(@manifiesto, @caja), params: { codigo: codigo }, as: :json
  end

  def json = JSON.parse(response.body)
end
