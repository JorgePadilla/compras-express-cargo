require "test_helper"

# PR-C6.23: el botón "Cambio de servicio" del modal de duplicado se queda en
# /etiquetar y abre el modal del destino de una vez.
#
# Yusef, 2026-08-08:
#
#   "Cambio de servicio **envía donde no es**."
#   "Para mí que si hacemos cambio de servicio nada más al producto, nos tire
#    de un solo a esta ventana. Si yo presiono cambio de servicio, **me tire
#    aquí de un solo a esto**."
#   "Es que ellos no manejan la página de paquetes."
#
# Es la misma queja que ya había hecho por la otra opción del mismo modal
# ("me mandaste a editar y yo no quiero editar mi paquete", PR-C6.10). Quedó a
# medias: se arregló "Es actualización" y no "Cambio de servicio".
#
# Ojo con lo que **no** hay que arreglar: marcar el check a mano ya abre el
# modal al instante, sin ida al servidor (`checkbox_modal_controller`). Ese
# camino estaba bien.
class EtiquetarCambioServicioModalTest < ActionDispatch::IntegrationTest
  MARCA_ABIERTO = /data-checkbox-modal-abrir-al-cargar-value="true"/

  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: tipo_envios(:cer).id, sucursal_recepcion_id: sucursales(:miami).id }
    @paquete = paquetes(:recibido)
  end

  test "llegar con cambio_servicio abre el modal del destino" do
    get etiquetar_url(paquete_id: @paquete.id, cambio_servicio: 1)

    assert_response :success
    assert_match MARCA_ABIERTO, response.body
  end

  test "cargar el paquete sin pedir cambio de servicio no abre nada" do
    get etiquetar_url(paquete_id: @paquete.id)

    assert_response :success
    assert_no_match MARCA_ABIERTO, response.body
  end

  test "entrar limpio a etiquetar tampoco abre nada" do
    get etiquetar_url

    assert_response :success
    assert_no_match MARCA_ABIERTO, response.body
  end

  test "sin paquete cargado no tiene sentido abrirlo" do
    # `cambio_servicio` solo aplica sobre un paquete que ya existe. Suelto en
    # la URL no puede abrir un modal que pregunta por el destino de nada.
    get etiquetar_url(cambio_servicio: 1)

    assert_response :success
    assert_no_match MARCA_ABIERTO, response.body
  end

  test "si no eligio destino, el modal vuelve abierto con el error" do
    # Antes el 422 re-renderizaba con el check marcado y el modal cerrado: el
    # mensaje pedía elegir algo que no estaba a la vista.
    post etiquetar_url, params: {
      paquete: {
        tracking: "1Z999MODAL0001", cliente_id: clientes(:juan).id,
        descripcion: "Cosas", peso: 5, solicito_cambio_servicio: "1"
      }
    }

    assert_response :unprocessable_entity
    assert_match MARCA_ABIERTO, response.body
    assert_match(/elegí a qué tipo de envío cambia/, response.body)
  end

  test "un error que no es del cambio de servicio no abre el modal" do
    post etiquetar_url, params: {
      paquete: { tracking: "", cliente_id: clientes(:juan).id, descripcion: "Cosas", peso: 5 }
    }

    assert_response :unprocessable_entity
    assert_no_match MARCA_ABIERTO, response.body
  end
end
