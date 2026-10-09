require "application_system_test_case"

# PR-C6.33: buscar el cliente en /pre_alertas/new se comporta igual que en
# /etiquetar y /entrega_personal.
#
# Yusef lo pidió en el audio del 2026-08-08, sobre esta pantalla:
#
#   "Preseleccionar de los dropdown."
#
# Lo tenía anotado como A3-10 y lo había leído como un cambio de UI. Al ir a
# tocarlo resultó ser dos cosas, las dos más chicas de lo que parecían:
#
#   1. el input no tenía cableado el `keydown`, así que el controller —que
#      siempre supo manejar flechas y Enter— nunca los recibía en esta pantalla
#   2. `client-autocomplete` nunca preseleccionaba el primer resultado
#
# Tercer archivo espejo de `etiquetar_busqueda_cliente_test.rb`: si todas las
# pantallas tienen que comportarse igual, sus tests tienen que poder leerse en
# paralelo.
class PreAlertasBusquedaClienteTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:admin))

    visit new_pre_alerta_path
    assert_selector "[data-client-autocomplete-target=input]", wait: 5
  end

  test "un solo digito abre la lista" do
    buscar("2")

    assert_selector "[data-index]", wait: 5
    assert_text "CEC-002"
  end

  test "el que uno busca sale primero y preseleccionado" do
    buscar("2")
    assert_selector "[data-index]", wait: 5

    primero = all("[data-index]").first
    assert_equal "CEC-002", primero.find("span.font-mono").text
    assert primero[:class].include?("bg-cec-teal/10"), "el primero no quedó preseleccionado"
  end

  test "Enter toma el preseleccionado sin usar el mouse" do
    buscar("2")
    assert_selector "[data-index]", wait: 5

    find("[data-client-autocomplete-target=input]").send_keys(:enter)

    assert_equal clientes(:maria).id.to_s,
                 page.evaluate_script("document.querySelector('[data-client-autocomplete-target=clienteId]').value")
  end

  test "Enter sobre el dropdown no envia el formulario" do
    # La pre-alerta se guarda con un botón; si Enter la enviara, se crearía a
    # medias apenas el operario elige el cliente.
    buscar("2")
    assert_selector "[data-index]", wait: 5

    find("[data-client-autocomplete-target=input]").send_keys(:enter)

    assert_current_path new_pre_alerta_path
  end

  test "una sola letra NO abre la lista" do
    buscar("a")

    assert_no_selector "[data-index]", wait: 2
  end

  test "el campo queda con el codigo y el nombre" do
    # Lo propio de esta pantalla: es un form de captura, no una estación de
    # escaneo — acá el operario quiere leer a quién eligió.
    buscar("2")
    assert_selector "[data-index]", wait: 5

    find("[data-client-autocomplete-target=input]").send_keys(:enter)

    assert_match(/CEC-002 — /, find("[data-client-autocomplete-target=input]").value)
  end

  private

  def buscar(texto)
    campo = find("[data-client-autocomplete-target=input]")
    campo.click
    campo.send_keys(texto)
  end
end
