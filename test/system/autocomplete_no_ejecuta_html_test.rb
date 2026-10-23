require "application_system_test_case"

# Lo que viene del JSON se escapa antes de ir a `innerHTML`.
#
# Lo marcó la revisión de Gemini en #569, y venía de antes: cada `_filaHtml`
# metía el nombre del cliente tal cual. Un cliente se registra solo desde el
# portal, así que un nombre con HTML corría en el navegador del personal
# apenas lo buscaba.
class AutocompleteNoEjecutaHtmlTest < ApplicationSystemTestCase
  NOMBRE = %(<img src=x onerror="window.__xss=1">Malo).freeze

  setup do
    clientes(:juan).update_columns(nombre: NOMBRE)
    ingresar(users(:admin))
    visit new_pre_alerta_path
    assert_selector "[data-client-autocomplete-target=input]", wait: 5
  end

  test "el nombre del cliente se muestra como texto y no corre" do
    find("[data-client-autocomplete-target=input]").set("CEC-001")
    assert_selector "[role=option]", wait: 5

    assert_text NOMBRE
    assert_nil page.evaluate_script("window.__xss"), "el HTML del nombre se ejecutó"
    assert_no_selector "[role=option] img"
  end

  test "elegirlo pone el nombre entero, con sus comillas" do
    find("[data-client-autocomplete-target=input]").set("CEC-001")
    assert_selector "[role=option]", wait: 5

    find("[data-client-autocomplete-target=input]").send_keys(:enter)

    assert_includes find("[data-client-autocomplete-target=input]").value, NOMBRE
    assert_nil page.evaluate_script("window.__xss")
  end

  # El `dataset` decodifica lo que el servidor escapó: el resumen de «Mover a
  # Pre-Alerta Existente» lo volvía a pintar con `innerHTML` tal cual.
  test "el título de la pre-alerta en el resumen de Mover se muestra como texto" do
    pre_alertas(:maria_pa).update_columns(titulo: NOMBRE)
    visit paquete_path(paquetes(:recibido))
    click_on "Mover a otra Pre-Alerta"

    find("[data-mover-pre-alerta-modal-target=input]").set(pre_alertas(:maria_pa).numero_documento)
    assert_selector "[data-mover-pre-alerta-modal-target=results] [data-index]", wait: 5
    find("[data-mover-pre-alerta-modal-target=input]").send_keys(:enter)

    within("[data-mover-pre-alerta-modal-target=selectedSummary]") { assert_text NOMBRE }
    assert_no_selector "[data-mover-pre-alerta-modal-target=selectedSummary] img"
    assert_nil page.evaluate_script("window.__xss")
  end
end
