require "application_system_test_case"

# PR-C29.16 · «Signos del servidor» en Chrome: se llega desde el ícono del
# Home, y «Actualizar» vuelve a pedir las medidas sin recargar la página.
class SignosVitalesTest < ApplicationSystemTestCase
  setup { ingresar(users(:admin)) }

  test "del ícono del Home a la página, y «Actualizar» trae medidas nuevas" do
    visit root_path
    find("a[aria-label^='Signos del servidor']").click
    assert_selector "h1", text: "Signos del servidor", wait: 5
    assert_selector "section[data-seccion]", count: 4

    # Una marca adentro del frame: si el frame se vuelve a pedir, el nodo se
    # reemplaza y la marca se va. Una página recargada entera también la
    # borraría, por eso se marca además la ventana.
    page.execute_script("document.querySelector('#signos_vitales [data-nivel]').dataset.marca = 'vieja'; window.__misma = true")
    click_on "Actualizar"

    assert_no_selector "#signos_vitales [data-marca='vieja']", wait: 5
    assert_selector "section[data-seccion]", count: 4
    assert page.evaluate_script("window.__misma === true"), "«Actualizar» recargó la página entera en vez del frame"
  end
end
