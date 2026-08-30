require "test_helper"

# C20-04: lo que el operario contesta en «¿cuántas etiquetas?» es la cantidad
# de cajas del envío. Yusef: *"en impresión de etiquetas es el que te marca la
# cantidad de cajas"*.
#
# Este es el camino REAL de la pantalla —el parámetro suelto `etiquetas`, que
# manda el modal— y hasta ahora ningún test lo recorría: los que había usaban
# `paquete[cantidad_paquetes]`, un campo que la pantalla dejó de mandar hace
# rato. Por eso pasó desapercibido que confirmar «1» no hacía nada.
#
# Y con la cantidad nueva salen TODAS las etiquetas otra vez, que es lo que
# Yusef pidió: *"tenés que imprimirlas todas, porque si no en San Pedro
# también ocasiona malentendido: ellos creen, ah, si son tres… pero este dice
# cuatro y usted dice tres"*.
class EtiquetarCantidadDeEtiquetasTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @cer = tipo_envios(:cer)
    @miami = sucursales(:miami)
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: @cer.id, sucursal_recepcion_id: @miami.id }
  end

  test "de 3 a 2 — «ese celular hay que devolverlo»" do
    cajas = crear_split(3)

    actualizar(cajas.first, etiquetas: 2)

    quedan = del_envio(cajas.first)
    assert_equal [ 1, 2 ], quedan.map(&:numero_caja)
    assert_equal [ 2, 2 ], quedan.map(&:cantidad_paquetes)
  end

  test "de 3 a 1 — el caso que era inexpresable" do
    cajas = crear_split(3)

    actualizar(cajas.first, etiquetas: 1)

    quedan = del_envio(cajas.first)
    assert_equal 1, quedan.size, "confirmar «1» se descartaba en silencio"
    assert_equal 1, quedan.first.cantidad_paquetes
    assert_not quedan.first.dividido?, "sin split, la etiqueta ya no lleva fracción"
  end

  test "de 1 a 3 — el reempaque que no cabía" do
    paquete = crear_recibido

    # C20-12: la caja tenía 5 lb, así que al partirla se pesa cada una — es
    # lo que el modal manda en su segundo paso. Sin los pesos, el servidor la
    # rechaza (`etiquetar_pesar_al_partir_test`).
    actualizar(paquete, etiquetas: 3, pesos: { 1 => "2", 2 => "2", 3 => "1.5" })

    quedan = del_envio(paquete)
    assert_equal [ 1, 2, 3 ], quedan.map(&:numero_caja)
    assert_equal 1, quedan.map(&:numero_recepcion).uniq.size
    assert_equal [ 2.0, 2.0, 1.5 ], quedan.map { |c| c.peso.to_f }, "el 5 de la caja sola ya no vale"
  end

  test "contestar la misma cantidad no toca nada" do
    cajas = crear_split(2)

    actualizar(cajas.first, etiquetas: 2)

    assert_equal 2, del_envio(cajas.first).size
    assert_equal [ 1, 2 ], del_envio(cajas.first).map(&:numero_caja)
  end

  test "después de cambiar la cantidad se reimprimen TODAS, con el n/N nuevo" do
    cajas = crear_split(3)

    actualizar(cajas.first, etiquetas: 2, print: "true")
    assert_match(/data-print='true'/, response.body)

    # La impresión sale del evento con `hermanas=1`: de ahí tienen que salir
    # las dos que quedaron, cada una diciendo «de 2».
    quedan = del_envio(cajas.first)
    get etiqueta_paquete_url(quedan.first, hermanas: 1)

    assert_response :success
    assert_equal 2, response.body.scan(/class="etq"/).size,
                 "salieron etiquetas de más o de menos para el envío"
    assert_match ">1/2<", response.body
    assert_match ">2/2<", response.body
    assert_no_match(/\/3</, response.body, "quedó una fracción vieja: «este dice tres»")
  end

  private

  def actualizar(paquete, etiquetas:, print: nil, pesos: nil)
    cajas = pesos&.to_h { |i, peso| [ i.to_s, { peso: peso } ] }
    patch actualizar_etiquetar_url(paquete),
          params: { etiquetas: etiquetas, print: print,
                    paquete: { descripcion: "Perfumes", cajas: cajas }.compact }.compact,
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  def del_envio(paquete)
    Paquete.where(tracking: paquete.tracking).order(:numero_caja)
  end

  def crear_recibido
    Paquete.create!(
      tracking: "ETQ#{SecureRandom.hex(4)}", cliente: clientes(:juan), tipo_envio: @cer,
      sucursal_recepcion: @miami, estado: "recibido_miami", descripcion: "Perfumes",
      peso: 5, user: @user
    )
  end

  def crear_split(n)
    primero = crear_recibido
    primero.update_columns(numero_caja: 1, cantidad_paquetes: n)
    resto = (2..n).map do |i|
      Paquete.create!(
        tracking: primero.tracking, cliente: primero.cliente, tipo_envio: @cer,
        sucursal_recepcion: @miami, numero_recepcion: primero.numero_recepcion,
        estado: "recibido_miami", descripcion: "Perfumes", peso: 5,
        numero_caja: i, cantidad_paquetes: n, user: @user
      )
    end
    [ primero, *resto ]
  end
end
