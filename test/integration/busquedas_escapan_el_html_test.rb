require "test_helper"

# Los JSON que los buscadores pintan con `innerHTML` van escapados desde el
# servidor, como ya lo hacía `clientes#buscar`. Cuatro no lo hacían, y el
# título de una pre-alerta lo escribe el cliente desde el portal: un título
# con HTML corría en el navegador del personal. Lo marcó la revisión de Gemini
# en #569.
class BusquedasEscapanElHtmlTest < ActionDispatch::IntegrationTest
  HTML = %(<img src=x onerror="alert(1)">).freeze
  ESCAPADO = ERB::Util.html_escape(HTML).freeze

  setup do
    pre_alertas(:activa).update_columns(titulo: HTML)
    pre_alertas(:consolidada_destino).update_columns(titulo: HTML)
  end

  test "pre_alertas#buscar escapa el título y el cliente" do
    entrar_como_admin
    get buscar_pre_alertas_path(q: pre_alertas(:activa).numero_documento)

    fila = response.parsed_body.find { |pa| pa["id"] == pre_alertas(:activa).id }
    assert_equal ESCAPADO, fila["titulo"]
    assert_not_includes response.body, "<img"
  end

  test "proveedores#buscar escapa el nombre" do
    proveedores(:driver_entrega).update_columns(nombre: HTML)
    entrar_como_admin
    get buscar_proveedores_path(q: proveedores(:driver_entrega).codigo)

    assert_includes response.parsed_body.map { |p| p["nombre"] }, ESCAPADO
    assert_not_includes response.body, "<img"
  end

  test "destinos para mover, en admin, escapan el título" do
    entrar_como_admin
    get destinos_disponibles_pre_alerta_path(pre_alertas(:activa), pre_alerta_paquete_id: pre_alerta_paquetes(:pap_sin_vincular).id)

    assert_response :success
    assert_includes response.body, ESCAPADO.to_json[1..-2], "la lista no trajo el destino con el título"
    assert_not_includes response.body, "<img"
  end

  test "destinos para mover, en el portal, escapan el título" do
    post session_url, params: { email_address: clientes(:juan).email, password: "Cliente123!" }
    get destinos_disponibles_cuenta_pre_alerta_path(pre_alertas(:activa), pre_alerta_paquete_id: pre_alerta_paquetes(:pap_sin_vincular).id)

    assert_response :success
    assert_includes response.body, ESCAPADO.to_json[1..-2], "la lista no trajo el destino con el título"
    assert_not_includes response.body, "<img"
  end

  private

  def entrar_como_admin
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
  end
end
