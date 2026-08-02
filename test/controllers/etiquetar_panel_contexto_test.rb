require "test_helper"

# PR-9.b: /etiquetar monta la franja de contexto a la derecha del formulario.
# Vive aparte de etiquetar_controller_test.rb para no mezclar el flujo de
# guardado con el de la franja.
class EtiquetarPanelContextoTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:digitador).email_address,
                                password: "password123" }
    # Sin sesión de tipo de envío la pantalla muestra el chooser, no el form.
    post iniciar_sesion_etiquetar_url, params: { tipo_envio_id: tipo_envios(:express).id }
  end

  test "monta el turbo-frame de la franja" do
    get etiquetar_url

    assert_response :success
    assert_match "panel_contexto", response.body
    assert_match "data-etiquetar-target=\"panel\"", response.body
  end

  test "el formulario queda en la columna izquierda del grid" do
    get etiquetar_url

    assert_response :success
    assert_match "xl:grid-cols-12", response.body
  end
end
