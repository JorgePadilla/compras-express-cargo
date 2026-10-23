require "application_system_test_case"

# PR-A11Y.3 · El esqueleto de la página, con teclado y en el celular.
#
# El «Menú» del celular no abría nada en el admin. Desde el hover-expand
# (8e4b8b3) el controller del sidebar vivía en el `<aside>`, y el botón y el
# fondo oscuro están afuera: Stimulus no les encontraba controller. En el
# portal andaba porque ahí el controller está en el `<body>`. Las gemelas.
class MenuYSaltarAlContenidoTest < ApplicationSystemTestCase
  MENU = "button[aria-controls='sidebar']".freeze

  teardown { page.driver.browser.manage.window.resize_to(1400, 1400) }

  test "admin: en el celular el menú abre, avisa que está abierto, y Escape lo cierra" do
    ingresar(users(:admin))
    probar_el_menu_del_celular(proveedores_path)
  end

  test "portal: lo mismo en la gemela" do
    visit new_session_path
    fill_in "email_address", with: clientes(:juan).codigo
    fill_in "password", with: "Cliente123!"
    click_on "Iniciar Sesion"
    assert_current_path cuenta_root_path, wait: 5

    probar_el_menu_del_celular(cuenta_pre_alertas_path)
  end

  test "el primer Tab ofrece saltar el menú, y lleva al contenido" do
    ingresar(users(:admin))
    visit proveedores_path
    find("body").send_keys(:tab)

    assert_equal "Saltar al contenido", page.evaluate_script("document.activeElement.textContent.trim()")
    page.driver.browser.action.send_keys(:enter).perform

    assert_eventualmente("el foco no llegó al contenido") do
      page.evaluate_script("document.activeElement.id") == "contenido"
    end
  end

  test "en escritorio, el rail colapsado se abre cuando el foco entra" do
    ingresar(users(:admin))
    visit proveedores_path
    assert_selector "aside#sidebar.is-collapsed"

    page.execute_script("document.querySelector('#sidebar nav a').focus()")

    assert_no_selector "aside#sidebar.is-collapsed"
  end

  private

  def probar_el_menu_del_celular(ruta)
    page.driver.browser.manage.window.resize_to(400, 800)
    visit ruta
    assert_equal "false", find(MENU)["aria-expanded"]

    find(MENU).click

    assert_eventualmente("el menú no se abrió") { izquierda_del_sidebar >= 0 }
    assert_equal "true", find(MENU)["aria-expanded"]
    assert page.evaluate_script("document.getElementById('sidebar').contains(document.activeElement)"),
           "el foco no entró al menú"

    page.driver.browser.action.send_keys(:escape).perform

    assert_eventualmente("Escape no cerró el menú") { izquierda_del_sidebar.negative? }
    assert_equal "false", find(MENU)["aria-expanded"]
    assert_equal "sidebar", page.evaluate_script("document.activeElement.getAttribute('aria-controls')"),
                 "el foco no volvió al botón"
  end

  def izquierda_del_sidebar
    page.evaluate_script("document.getElementById('sidebar').getBoundingClientRect().left")
  end
end
