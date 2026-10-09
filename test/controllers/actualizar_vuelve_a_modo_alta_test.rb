require "test_helper"

# Jorge, 2026-08-19, con `/etiquetar` en la pantalla:
#
#   > *"«Actualizando 9234690331281800086052 · solo se guardan los datos que
#   >  Miami captura; el estado se cambia en Paquetes» — este siempre se queda
#   >  en la vista, no desaparece al guardar."*
#
# El banner era el síntoma visible. Lo de abajo es peor: el `form` se renderiza
# en el servidor apuntando a `PATCH /etiquetar/:id`, y `clearForm` limpia los
# **campos** pero no la acción. O sea que después de actualizar un paquete, el
# siguiente que se escaneara se guardaba **encima del anterior** — en silencio,
# en la pantalla más usada del sistema.
class ActualizarVuelveAModoAltaTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: {
      email_address: users(:digitador).email_address, password: "password123"
    }
    post iniciar_sesion_etiquetar_url, params: {
      tipo_envio_id: tipo_envios(:cer).id, sucursal_recepcion_id: sucursales(:miami).id
    }
    @paquete = Paquete.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                               tracking: "1ZACTUALIZAR0001", descripcion: "x",
                               estado: "recibido_miami", user: users(:digitador),
                               sucursal_recepcion: sucursales(:miami))
  end

  test "al actualizar, la respuesta pide volver a modo alta" do
    patch actualizar_etiquetar_url(@paquete),
          params: { paquete: { descripcion: "corregido" } },
          as: :turbo_stream

    assert_response :success
    assert_match(/data-volver='true'/, response.body)
  end

  test "al dar de alta NO se pide volver: la pantalla ya está lista" do
    # Ahí `clearForm` alcanza — el formulario ya apunta a `POST /etiquetar`.
    post etiquetar_url, params: { paquete: {
      tracking: "1ZALTANORMAL0001", cliente_id: clientes(:juan).id,
      descripcion: "x", peso: 10
    } }, as: :turbo_stream

    assert_response :success
    assert_no_match(/data-volver='true'/, response.body)
  end

  test "el banner de Actualizando sale solo con el paquete cargado" do
    get etiquetar_url(paquete_id: @paquete.id)
    assert_match(/Actualizando/, response.body)

    get etiquetar_url
    assert_no_match(/Actualizando/, response.body)
  end

  test "el formulario apunta a PATCH solo mientras se actualiza" do
    # La mitad que de verdad muerde: mientras el form apunte al paquete viejo,
    # lo que se escanee después se guarda encima de él.
    get etiquetar_url(paquete_id: @paquete.id)
    assert_match(%r{action="/etiquetar/#{@paquete.id}"}, response.body)

    get etiquetar_url
    assert_no_match(%r{action="/etiquetar/#{@paquete.id}"}, response.body)
  end

  test "la pantalla vuelve sola al terminar de actualizar" do
    # El otro extremo del cable: el server manda `data-volver` y alguien tiene
    # que escucharlo. Escrito y no llamado sería lo mismo que no tenerlo.
    src = Rails.root.join("app/javascript/controllers/etiquetar_controller.js").read
    metodo = src[/eventTargetConnected\(el\)\s*\{.*?\n  \}/m]
    assert metodo, "no se encontró eventTargetConnected"

    assert_includes metodo, "el.dataset.volver"
    assert_includes metodo, "Turbo.visit"
  end
end
