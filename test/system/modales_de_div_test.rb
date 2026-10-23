require "application_system_test_case"

# PR-A11Y.7 · Los modales hechos con un `div` se portan como un `<dialog>`:
# el foco entra, Tab no se escapa a la página tapada, Escape cierra y el foco
# vuelve al botón que lo abrió. Se prueba con «Buscar Paquetes» del portal;
# «Mover paquete» del admin usa el mismo helper (`modal_de_div.js`).
class ModalesDeDivTest < ApplicationSystemTestCase
  MODAL = "[data-pre-alerta-buscar-target=modal]".freeze

  setup do
    visit new_session_path
    fill_in "email_address", with: clientes(:juan).codigo
    fill_in "password", with: "Cliente123!"
    click_on "Iniciar Sesion"
    assert_current_path cuenta_root_path, wait: 5

    visit edit_cuenta_pre_alerta_path(pre_alertas(:activa))
  end

  test "el foco entra al filtro, Escape cierra y vuelve al botón" do
    click_on "Buscar Paquetes"
    assert_selector MODAL, visible: true

    assert_eventualmente("el foco no entró al filtro") do
      page.evaluate_script("document.activeElement.dataset.preAlertaBuscarTarget") == "filterInput"
    end
    assert_equal "Buscar Paquetes", find("##{find(MODAL)['aria-labelledby']}").text

    page.driver.browser.action.send_keys(:escape).perform

    assert_selector MODAL, visible: :hidden
    assert_equal "Buscar Paquetes", page.evaluate_script("document.activeElement.textContent.trim()")
  end

  test "Tab da la vuelta adentro del modal" do
    click_on "Buscar Paquetes"
    assert_selector MODAL, visible: true

    10.times { page.driver.browser.action.send_keys(:tab).perform }

    assert page.evaluate_script("document.querySelector(\"#{MODAL}\").contains(document.activeElement)"),
           "el foco se escapó a la página de atrás"
  end
end
