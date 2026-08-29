require "test_helper"

# C20-04: ajustar la cantidad de cajas al actualizar, en el orden correcto.
#
# La regla es de Yusef: *"en impresión de etiquetas es el que te marca la
# cantidad de cajas"*, con sus dos casos reales — de 3 a 2 porque *"el paquete
# lleva un celular… ese celular hay que devolverlo"*, y de 1 a 3 porque *"cuando
# lo queremos empacar no cabe: nos vamos a mesa, actualizamos, lo reempacamos
# en 2 bultos o 3"*.
#
# El ajuste corría ANTES de que el paquete tuviera número, y las hermanas se
# agrupan justamente por ese número: un envío sin número no se encontraba a sí
# mismo, y las cajas nuevas nacían copiando ese vacío. Cada una terminaba
# acuñándose el suyo y el envío quedaba partido para siempre.
class EtiquetarSplitOrdenadoTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @cer = tipo_envios(:cer)
    @miami = sucursales(:miami)
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: @cer.id, sucursal_recepcion_id: @miami.id }
  end

  test "un paquete sin número se acuña UNO y las cajas nuevas lo comparten" do
    paquete = crear_recibido
    paquete.update_columns(numero_recepcion: nil, sucursal_recepcion_id: nil,
                           warehouse_receipt_id: nil)

    patch actualizar_etiquetar_url(paquete), params: { paquete: { cantidad_paquetes: 3 } }

    cajas = Paquete.where(tracking: paquete.tracking).order(:numero_caja)
    assert_equal 3, cajas.size
    assert_equal 1, cajas.map(&:numero_recepcion).uniq.size,
                 "cada caja se acuñó su propio número: el envío queda partido para siempre"
    assert cajas.first.numero_recepcion.present?
    assert_equal 1, cajas.map(&:warehouse_receipt_id).uniq.size, "un WR por envío, no uno por caja"
    assert_equal [ 1, 2, 3 ], cajas.map(&:numero_caja)
    assert_equal [ 3, 3, 3 ], cajas.map(&:cantidad_paquetes)
    # Y con eso se encuentran entre sí, que es de lo que depende la impresión.
    assert_equal 2, cajas.first.paquetes_hermanos.count
  end

  test "reducir editando la caja que se va no revienta" do
    # Al re-escanear, «Es actualización» abre la caja MÁS NUEVA — justo la que
    # `ajustar_split!` borra primero. Seguir con ella era un RecordNotFound.
    cajas = crear_split(3)

    patch actualizar_etiquetar_url(cajas.last),
          params: { paquete: { cantidad_paquetes: 2 } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    quedan = Paquete.where(tracking: cajas.first.tracking).order(:numero_caja)
    assert_equal [ 1, 2 ], quedan.map(&:numero_caja)
    assert_equal [ 2, 2 ], quedan.map(&:cantidad_paquetes)
    # El evento apunta a una caja viva: de ahí sale la reimpresión de todas.
    assert_match(/data-paquete-id='(#{quedan.map(&:id).join('|')})'/, response.body)
  end

  test "el peso del formulario no se le pega a la caja que sobrevivió" do
    cajas = crear_split(3)
    cajas.first.update_columns(peso: 5)

    patch actualizar_etiquetar_url(cajas.last), params: {
      paquete: { cantidad_paquetes: 2, peso: 99 }
    }

    assert_equal 5, cajas.first.reload.peso.to_i,
                 "el peso era de la caja que se fue"
  end

  test "una caja ya cobrada bloquea el ajuste y no se guarda NADA" do
    cajas = crear_split(2)
    cajas.last.update_columns(estado: "pre_facturado")

    patch actualizar_etiquetar_url(cajas.first), params: {
      paquete: { cantidad_paquetes: 1, descripcion: "no tendría que quedar" }
    }

    assert_response :unprocessable_entity
    assert_equal 2, Paquete.where(tracking: cajas.first.tracking).count
    assert_not_equal "no tendría que quedar", cajas.first.reload.descripcion,
                     "el ajuste falló: no se guarda nada, ni lo que sí valía"
  end

  test "sobre un esperado no se ajusta: se recibe escaneándolo" do
    esperado = crear_recibido
    esperado.update_columns(estado: "pre_alerta_estado", numero_recepcion: nil,
                            sucursal_recepcion_id: nil, warehouse_receipt_id: nil)

    patch actualizar_etiquetar_url(esperado), params: { paquete: { cantidad_paquetes: 3 } }

    assert_response :unprocessable_entity
    assert_match(/todavía es un esperado/i, response.body)
    assert_equal 1, Paquete.where(tracking: esperado.tracking).count
  end

  test "actualizar sin tocar la cantidad sigue sin tocar el split" do
    cajas = crear_split(2)

    patch actualizar_etiquetar_url(cajas.first), params: {
      paquete: { descripcion: "corregida" }
    }

    assert_redirected_to etiquetar_path
    assert_equal 2, Paquete.where(tracking: cajas.first.tracking).count
    assert_equal "corregida", cajas.first.reload.descripcion
  end

  # La gemela: el acuñado vive en el modelo, así que /paquetes lo hereda.
  test "el acuñado también le llega a /paquetes" do
    paquete = crear_recibido
    paquete.update_columns(numero_recepcion: nil, warehouse_receipt_id: nil)

    Paquete.ajustar_split!(paquete, 2)

    assert paquete.reload.numero_recepcion.present?
    assert_equal 1, Paquete.where(tracking: paquete.tracking).map(&:numero_recepcion).uniq.size
  end

  private

  def crear_recibido
    Paquete.create!(
      tracking: "SPL#{SecureRandom.hex(4)}", cliente: clientes(:juan), tipo_envio: @cer,
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
