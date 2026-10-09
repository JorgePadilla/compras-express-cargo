require "application_system_test_case"

# PR-C6.16: teclear un solo dígito abre la lista de clientes.
#
# Jorge probándolo: "veo que si pongo 2 no me sale María, debe salir la lista".
#
# El autocomplete tenía un mínimo de **2 caracteres**, y eso bloqueaba justo la
# forma en que Miami trabaja. Yusef:
#
#   "Solo le ponían el dos, ponele que el mío es el seis, solo poníamos el seis
#    o el dos y ya con eso cae."
#
# El backend ya encontraba y ya ordenaba bien (PR-C6.14b) — `2` devuelve
# `CEC-002` primero. Lo que no dejaba llegar era el front.
#
# Va como system test porque el mínimo vive en JS: ningún test de integración
# lo puede ver.
class EtiquetarBusquedaClienteTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))

    abrir_sesion_etiquetar(TipoEnvio.activos.order(:nombre).first)
  end

  test "un solo digito abre la lista" do
    buscar("2")

    assert_selector "[data-index]", wait: 5
    assert_text "CEC-002"
  end

  test "el que uno busca sale primero y preseleccionado" do
    # `_clienteActiveIndex = 0` tras renderizar: Enter toma ese sin tocar el
    # mouse, que es todo el punto de trabajar con teclado.
    buscar("2")
    assert_selector "[data-index]", wait: 5

    primero = all("[data-index]").first
    assert_equal "CEC-002", primero.find("span.font-mono").text
    assert primero[:class].include?("bg-cec-teal/10"), "el primero no quedó preseleccionado"
  end

  test "Enter toma el preseleccionado sin usar el mouse" do
    buscar("2")
    assert_selector "[data-index]", wait: 5

    find("[data-etiquetar-target=clienteInput]").send_keys(:enter)

    assert_equal clientes(:maria).id.to_s,
                 page.evaluate_script("document.querySelector('[data-etiquetar-target=clienteId]').value")
  end

  test "una sola letra NO abre la lista" do
    # Buscar "a" devolvería la cartera entera: el dropdown sería ruido.
    buscar("a")

    assert_no_selector "[data-index]", wait: 2
  end

  private

  def buscar(texto)
    campo = find("[data-etiquetar-target=clienteInput]")
    campo.click
    campo.send_keys(texto)
  end
end
