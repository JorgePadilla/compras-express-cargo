require "test_helper"

# C20-12. Yusef, 2026-08-30, cuando Jorge le llevó `RP-51` —las cajas nuevas
# heredaban el peso de la caja 1, así que una de 5 lb partida en tres eran
# tres de 5 lb—:
#
#   > "Si no tiene pesos, pues los ponemos sin pesos. Pero si ya tiene pesos,
#   >  tenemos que obligarlo a llenar, para evitar esta incoherencia."
#
# Acá va el «obligar»: subir las cajas de un envío que ya tiene peso exige el
# peso de cada una, la original incluida — el peso de una caja sola era el del
# envío entero, y después de reempacar ya no vale. El modal lo pide en
# pantalla; esto es el servidor exigiéndolo aunque alguien salte el JS.
class EtiquetarPesarAlPartirTest < ActionDispatch::IntegrationTest
  # Lo que manda el navegador con Turbo: stream primero, html de respaldo.
  ACCEPT = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze

  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @cer = tipo_envios(:cer)
    @miami = sucursales(:miami)
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: @cer.id, sucursal_recepcion_id: @miami.id }
  end

  test "partir un envío con peso sin pesar cada caja se rechaza, y no toca nada" do
    paquete = crear_recibido(peso: 5)

    patch actualizar_etiquetar_url(paquete), params: { paquete: { peso: 5 }, etiquetas: 3 }, headers: ACCEPT

    assert_response :unprocessable_entity
    assert_match(/pesar cada una/, response.body)
    assert_equal 1, Paquete.where(tracking: paquete.tracking).count, "partió igual"
    assert_equal 5, paquete.reload.peso.to_i
  end

  test "con los pesos incompletos también se rechaza" do
    paquete = crear_recibido(peso: 5)

    patch actualizar_etiquetar_url(paquete),
          params: { paquete: { peso: 5, cajas: { "1" => { peso: "2" }, "3" => { peso: "1" } } }, etiquetas: 3 },
          headers: ACCEPT

    assert_response :unprocessable_entity
    assert_equal 1, Paquete.where(tracking: paquete.tracking).count
  end

  test "con el peso de cada caja parte y pesa — y el peso viejo del formulario no pisa el nuevo" do
    paquete = crear_recibido(peso: 5)

    # El formulario manda `paquete[peso]=5` pre-llenado, como siempre; el
    # modal manda los tres pesos. Mandan los del modal, también para la caja 1.
    patch actualizar_etiquetar_url(paquete),
          params: { paquete: { peso: 5, cajas: { "1" => { peso: "2" }, "2" => { peso: "2" }, "3" => { peso: "1.5" } } },
                    etiquetas: 3 },
          headers: ACCEPT

    assert_response :success
    cajas = Paquete.where(tracking: paquete.tracking).order(:numero_caja)
    assert_equal [ 2.0, 2.0, 1.5 ], cajas.map { |c| c.peso.to_f }
  end

  test "un envío sin peso se parte sin preguntar, y las cajas nacen sin peso" do
    paquete = crear_recibido(peso: nil)

    patch actualizar_etiquetar_url(paquete), params: { paquete: { peso: "" }, etiquetas: 3 }, headers: ACCEPT

    assert_response :success
    assert_equal [ nil, nil, nil ], Paquete.where(tracking: paquete.tracking).order(:numero_caja).map(&:peso)
  end

  test "bajar cajas no pide pesos" do
    cajas = crear_split(3, peso: 4)

    patch actualizar_etiquetar_url(cajas.last), params: { paquete: { peso: 4 }, etiquetas: 2 }, headers: ACCEPT

    assert_response :success
    assert_equal 2, Paquete.where(tracking: cajas.first.tracking).count
  end

  test "corregir el peso sin tocar la cantidad sigue entrando, aunque vengan filas sueltas" do
    # La guarda del `except`: el peso del formulario se ignora solo cuando los
    # pesos del modal se aplicaron de verdad. Una corrección normal —la
    # actualización más común de la mesa— tiene que entrar, y las filas del
    # repetidor que el update siempre ignoró se siguen ignorando.
    paquete = crear_recibido(peso: 5)

    patch actualizar_etiquetar_url(paquete),
          params: { paquete: { peso: 7, cajas: { "1" => { peso: "9" } } } },
          headers: ACCEPT

    assert_response :success
    assert_equal 7, paquete.reload.peso.to_i
  end

  private

  def crear_recibido(peso:)
    Paquete.create!(
      tracking: "PES#{SecureRandom.hex(4)}", cliente: clientes(:juan), tipo_envio: @cer,
      sucursal_recepcion: @miami, estado: "recibido_miami", descripcion: "Perfumes",
      peso: peso, user: @user
    )
  end

  def crear_split(n, peso:)
    primero = crear_recibido(peso: peso)
    primero.update_columns(numero_caja: 1, cantidad_paquetes: n)
    resto = (2..n).map do |i|
      Paquete.create!(
        tracking: primero.tracking, cliente: primero.cliente, tipo_envio: @cer,
        sucursal_recepcion: @miami, numero_recepcion: primero.numero_recepcion,
        estado: "recibido_miami", descripcion: "Perfumes", peso: peso,
        numero_caja: i, cantidad_paquetes: n, user: @user
      )
    end
    [ primero, *resto ]
  end
end
