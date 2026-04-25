require "test_helper"

# Verifica el flow end-to-end del icono PA en /paquetes:
#   1. Admin loguea
#   2. /paquetes renderiza el listado
#   3. Para un paquete con pre-alerta asociada, el href del link PA debe
#      apuntar a `pre_alerta_path` (admin), NO a `cuenta_pre_alerta_path`
#      (portal cliente).
#   4. Seguir el link debe responder 200 (admin tiene acceso).
#   5. Un usuario sin sesión es enviado a /session/new.
class PaquetesPreAlertaLinkFlowTest < ActionDispatch::IntegrationTest
  def login_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  test "admin: link PA en /paquetes apunta al admin pre_alerta_path y abre el detalle" do
    paquete   = paquetes(:recibido)
    pre_alerta = pre_alertas(:recibida)
    assert_equal pre_alerta, paquete.pre_alerta_paquetes.first&.pre_alerta,
                 "fixture sanity: paquete recibido debe tener pre_alerta vinculada"

    login_as users(:admin)
    get paquetes_url(incluir_mas_1_ano: "1")
    assert_response :success

    expected_href  = pre_alerta_path(pre_alerta)
    forbidden_href = cuenta_pre_alerta_path(pre_alerta)

    assert_includes response.body, %(href="#{expected_href}"),
      "Esperaba que el link PA apuntara al admin pre_alerta_path"
    assert_not_includes response.body, %(href="#{forbidden_href}"),
      "El link PA NO debe apuntar al portal del cliente cuenta_pre_alerta_path"

    # Seguir el link como admin debe llegar a la vista de detalle.
    get expected_href
    assert_response :success
    assert_match pre_alerta.numero_documento, response.body
  end

  test "usuario sin sesion: pre_alerta_path redirige al login" do
    get pre_alerta_url(pre_alertas(:recibida))
    assert_redirected_to new_session_url
  end
end
