require "test_helper"

# PR-C6.10: Miami actualiza sus datos en la MISMA hoja donde los llenó.
#
# Antes, "Es actualización" mandaba a `/paquetes/:id/edit`. Yusef lo cortó en
# seco:
#
#   "Me mandaste a editar y yo no quiero editar mi paquete."
#   "Que te cargue aquí la lista. Esto te lo vuelve a llenar tal cual como
#    quedó, y actualizan todo lo que quieran actualizar, porque eso es lo que
#    ellos ocupan."
#
# Contó los pasos en voz alta —editar, guardar, volver, re-imprimir,
# seleccionar— y ahí se le acabó la paciencia.
#
# **La línea divisoria la definió él y se respeta en el servidor:**
#
#   "Si ellos entran a actualizar acá es porque van a actualizar **datos del
#    paquete**, de lo que ellos ingresan." · "Si van a actualizar un **estado**
#    actual del paquete, eso sí lo van a tener que hacer en todos los paquetes."
class EtiquetarActualizarTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @cer = tipo_envios(:cer)
    @cem = tipo_envios(:cem)
    @miami = sucursales(:miami)
    iniciar_sesion_en(@cer)

    @paquete = Paquete.create!(
      tracking: "UPD#{SecureRandom.hex(4)}",
      cliente: clientes(:juan),
      tipo_envio: @cem,
      sucursal_recepcion: @miami,
      estado: "empacado",
      descripcion: "descripción vieja",
      peso: 5,
      user: @user
    )
  end

  test "el formulario se recarga con los datos del paquete" do
    get etiquetar_url, params: { paquete_id: @paquete.id }

    assert_response :success
    assert_match @paquete.tracking, response.body
    assert_match "descripción vieja", response.body
    assert_match(/Actualizando/, response.body)
  end

  test "actualiza los datos que Miami captura" do
    patch actualizar_etiquetar_url(@paquete), params: {
      paquete: { descripcion: "zapatos nuevos", peso: 12, expedido_por: "FedEx" }
    }

    @paquete.reload
    assert_equal "zapatos nuevos", @paquete.descripcion
    assert_equal 12, @paquete.peso
    assert_equal "FedEx", @paquete.expedido_por
  end

  test "el estado NO se toca desde etiquetar" do
    # La línea divisoria de Yusef. Si esto se rompe, Miami puede mover paquetes
    # por el pipeline desde una pantalla que no fue hecha para eso.
    patch actualizar_etiquetar_url(@paquete), params: {
      paquete: { descripcion: "x", estado: "entregado" }
    }

    assert_equal "empacado", @paquete.reload.estado,
                 "se cambió el estado desde /etiquetar"
  end

  test "la sesion NO le pisa el tipo de envio al actualizar" do
    # El paquete es CEM y la sesión es CER. Corregirle el peso no puede
    # convertirlo en CER — la sesión manda al CREAR, no al actualizar.
    patch actualizar_etiquetar_url(@paquete), params: { paquete: { peso: 9 } }

    assert_equal @cem, @paquete.reload.tipo_envio,
                 "la sesión le cambió el servicio al actualizar"
  end

  test "el cambio de servicio si mueve el tipo, porque es explicito" do
    patch actualizar_etiquetar_url(@paquete), params: {
      paquete: { solicito_cambio_servicio: "1", tipo_envio_destino_id: @cer.id }
    }

    @paquete.reload
    assert_equal @cer, @paquete.tipo_envio
    assert_equal @cem, @paquete.tipo_envio_anterior
  end

  test "cambiar la cantidad de cajas ajusta el split" do
    cajas = Paquete.crear_split!(
      attrs: {
        tracking: "UPDSPL#{SecureRandom.hex(3)}", cliente: clientes(:juan),
        tipo_envio: @cer, sucursal_recepcion: @miami, estado: "empacado",
        descripcion: "x", user: @user
      },
      total_cajas: 3
    )

    patch actualizar_etiquetar_url(cajas.first), params: { paquete: { cantidad_paquetes: 2 } }

    assert_equal 2, Paquete.where(numero_recepcion: cajas.first.numero_recepcion).count
  end

  test "no deja borrar una caja ya facturada" do
    cajas = Paquete.crear_split!(
      attrs: {
        tracking: "UPDFAC#{SecureRandom.hex(3)}", cliente: clientes(:juan),
        tipo_envio: @cer, sucursal_recepcion: @miami, estado: "empacado",
        descripcion: "x", user: @user
      },
      total_cajas: 3
    )
    cajas.last.update_columns(estado: "facturado")

    patch actualizar_etiquetar_url(cajas.first), params: { paquete: { cantidad_paquetes: 2 } }

    assert_response :unprocessable_entity
    assert_equal 3, Paquete.where(numero_recepcion: cajas.first.numero_recepcion).count
  end

  test "actualizar no crea un paquete nuevo" do
    assert_no_difference -> { Paquete.count } do
      patch actualizar_etiquetar_url(@paquete), params: { paquete: { descripcion: "y" } }
    end
  end

  test "sin paquete_id el formulario sigue siendo de alta" do
    get etiquetar_url

    assert_response :success
    assert_no_match(/Actualizando/, response.body)
  end

  private

  def iniciar_sesion_en(tipo)
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: tipo.id, sucursal_recepcion_id: @miami.id }
  end
end
