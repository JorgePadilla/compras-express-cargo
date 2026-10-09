require "test_helper"

# `A7-08` · Recibir el manifiesto **interno** en la sucursal destino.
#
# Yusef, describiendo lo que ya hacen a mano: *"yo veo que escanean el manifiesto
# y empiezan a **escanear paquete por paquete** para cuadrar el manifiesto"*. El
# interno lleva carga suelta, no casas armadas, así que la unidad que la pistola
# lee es el paquete.
#
# Y llega a `disponible_entrega` **en la sucursal destino**, que es lo que
# `A7-13` pide que el cliente vea: *"Disponible en sucursal Tegucigalpa"*.
class RecibirManifiestoInternoTest < ActionDispatch::IntegrationTest
  setup do
    @manifiesto = Manifiesto.create!(
      tipo: "interno", estado: "enviado",
      sucursal_origen: sucursales(:zeron_sps),
      sucursal_entrega: sucursales(:humuya_tgu),
      tipo_envios: [ tipo_envios(:cer) ]
    )
    @a = paquete_en_camino
    @b = paquete_en_camino
    ingresar(users(:supervisor_prefactura))
  end

  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def paquete_en_camino
    Paquete.create!(
      tracking: "1Z#{SecureRandom.hex(5).upcase}",
      cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
      sucursal_recepcion: sucursales(:miami), sucursal: sucursales(:humuya_tgu),
      sucursal_destino: sucursales(:humuya_tgu),
      estado: "enviado_sucursal", descripcion: "Perfumes", peso: 5,
      user: users(:digitador), manifiesto: @manifiesto
    )
  end

  def servicio = RecibirManifiesto.new(@manifiesto.reload)

  # ── El escaneo ──────────────────────────────────────────────────────────

  test "escanear un paquete lo deja disponible en la sucursal destino" do
    post escanear_recepcion_carga_url(@manifiesto), params: { codigo: @a.tracking }

    assert_equal "ok", response.parsed_body["resultado"]
    @a.reload
    assert_equal "disponible_entrega", @a.estado
    assert_equal sucursales(:humuya_tgu), @a.sucursal_actual,
                 "quedó disponible sin decir dónde: es justo lo que A7-13 vino a arreglar"
  end

  test "un código que no viene en el manifiesto se rechaza" do
    post escanear_recepcion_carga_url(@manifiesto), params: { codigo: "1ZLOQUESEA" }

    assert_equal "no_es_de_aqui", response.parsed_body["resultado"]
  end

  test "escanear dos veces el mismo avisa, no lo cuenta de nuevo" do
    post escanear_recepcion_carga_url(@manifiesto), params: { codigo: @a.tracking }
    post escanear_recepcion_carga_url(@manifiesto), params: { codigo: @a.tracking }

    assert_equal "ya_recibida", response.parsed_body["resultado"]
    assert_equal 1, servicio.paquetes_pendientes.count
  end

  test "el manifiesto pasa a en_aduana mientras se recibe: parcial es legítimo" do
    post escanear_recepcion_carga_url(@manifiesto), params: { codigo: @a.tracking }

    assert_equal "en_aduana", @manifiesto.reload.estado
  end

  # ── Cerrar, y la diferencia de fondo con el oficial ─────────────────────
  #
  # El oficial, al cerrar con faltantes, mueve igual **todos** los paquetes: la
  # caja que no apareció ya está perdida y no cerrar no la trae.
  #
  # El interno no puede hacer eso. `A7-09`: *"qué paquete no escanearon o no
  # enviaron… ey, este sale pendiente, hay que buscarlo"*. Marcar disponible al
  # que no llegó sería decirle al cliente que venga a retirar algo que no está.

  test "no cierra de una si falta alguno: avisa y ofrece las dos salidas" do
    patch finalizar_recepcion_carga_url(@manifiesto)

    assert_redirected_to recepcion_carga_path(@manifiesto)
    assert_match(/Faltan 2 de 2 paquete/, flash[:alert])
    assert_match(/pendientes/, flash[:alert])
    assert_equal "enviado", @manifiesto.reload.estado, "no se cerró"
  end

  test "cerrar con faltantes deja al que no llegó señalado, no disponible" do
    post escanear_recepcion_carga_url(@manifiesto), params: { codigo: @a.tracking }
    patch finalizar_recepcion_carga_url(@manifiesto, con_faltantes: true)

    assert_equal "recibido", @manifiesto.reload.estado
    assert_equal "disponible_entrega", @a.reload.estado
    assert_equal "enviado_sucursal", @b.reload.estado,
                 "se marcó disponible un paquete que no llegó: el cliente vendría a buscarlo en vano"
  end

  test "con todos escaneados cierra limpio" do
    post escanear_recepcion_carga_url(@manifiesto), params: { codigo: @a.tracking }
    post escanear_recepcion_carga_url(@manifiesto), params: { codigo: @b.tracking }

    patch finalizar_recepcion_carga_url(@manifiesto)

    assert_redirected_to recepcion_carga_index_path
    assert_equal "recibido", @manifiesto.reload.estado
    assert_equal 0, servicio.paquetes_pendientes.count
  end

  # `A7-06` · El correo de faltantes es del **internacional**: *"si falta una
  # caja, manda un correo al correo tal"*. En el interno el faltante no se pierde
  # de vista — se queda señalado, que es lo que `A7-09` pidió.
  test "cerrar el interno con faltantes no manda el correo del internacional" do
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      patch finalizar_recepcion_carga_url(@manifiesto, con_faltantes: true)
    end
  end

  # ── La pantalla ─────────────────────────────────────────────────────────

  test "la pantalla habla de paquetes, no de cajas" do
    get recepcion_carga_url(@manifiesto)

    assert_response :success
    assert_select "body", text: /Escaneá el paquete/
    assert_select "body", text: /0 de 2 recibidos/
  end

  test "el interno aparece en la lista de lo que hay que recibir" do
    get recepcion_carga_index_url

    assert_select "body", text: /#{@manifiesto.numero}/
  end
end
