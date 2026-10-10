require "application_system_test_case"

# C30-02 · Las teclas de la hoja de Yusef, en todo el sistema: F1 crear, F8
# guardar. La hoja (foto 2): *"F8 → Guardar · F9 → Guardar e Imprimir · F2 →
# Limpiar · F5 → Agregar · F4 → Imprimir · F1 → Crear"*.
#
# Lo que el lint (`teclas_por_familia_test`) no puede ver: que la tecla de
# verdad haga algo, y que F1 no deje pasar la Ayuda del navegador.
class TeclasDeLaHojaTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:admin))
  end

  test "F1 abre el formulario de uno nuevo" do
    visit proveedores_path
    find("body").click
    page.driver.browser.action.send_keys(:f1).perform

    assert_current_path new_proveedor_path, wait: 5
  end

  test "F1 se frena siempre, aunque el foco esté en un campo y no haya botón «Nuevo»" do
    # En Windows, un F1 que nadie frena abre la Ayuda de Chrome. El Chrome de
    # los tests no la abre, así que lo que se afirma es que el `keydown` llegó
    # frenado (`defaultPrevented`). ⚠️ La prueba de verdad es a mano, en las
    # máquinas Windows del equipo (ver `keyboard_shortcuts_controller.js`).
    visit new_proveedor_path
    page.execute_script(<<~JS)
      window.__f1 = null
      window.addEventListener("keydown", (e) => { if (e.key === "F1") window.__f1 = e.defaultPrevented })
    JS
    find("#proveedor_nombre").click
    page.driver.browser.action.send_keys(:f1).perform

    hasta_que("el F1 no llegó a la página") { !page.evaluate_script("window.__f1").nil? }
    assert page.evaluate_script("window.__f1"), "F1 pasó sin frenar: en Windows abre la Ayuda de Chrome"
    assert_current_path new_proveedor_path
  end

  test "F8 guarda" do
    visit new_proveedor_path
    find("#proveedor_nombre").set("Tienda F8")
    find("body").click
    page.driver.browser.action.send_keys(:f8).perform

    hasta_que("F8 no guardó") { Proveedor.exists?(nombre: "Tienda F8") }
  end

  test "F10 y F7 ya no hacen nada" do
    visit new_proveedor_path
    find("#proveedor_nombre").set("Tienda F10")
    find("body").click
    page.driver.browser.action.send_keys(:f10).perform
    page.driver.browser.action.send_keys(:f7).perform

    page.evaluate_script("new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)))")
    assert_current_path new_proveedor_path
    assert_not Proveedor.exists?(nombre: "Tienda F10")
  end

  test "el portal del cliente también escucha las teclas" do
    # Mostraba «Nueva Pre-Alerta (F7)» y nadie la escuchaba: el atajo global
    # vivía solo en el layout de admin.
    Capybara.reset_sessions!
    visit new_session_path
    fill_in "email_address", with: clientes(:juan).codigo
    fill_in "password", with: "Cliente123!"
    click_on "Iniciar Sesion"
    assert_current_path cuenta_root_path, wait: 5

    visit cuenta_pre_alertas_path
    find("body").click
    page.driver.browser.action.send_keys(:f1).perform

    assert_current_path new_cuenta_pre_alerta_path, wait: 5
  end

  private

  # Lo que no es un nodo, con la paciencia de Capybara (el bucle `synchronize`
  # de sus matchers), sin `sleep`.
  def hasta_que(mensaje, wait: Capybara.default_max_wait_time)
    page.document.synchronize(wait, errors: [ Capybara::ExpectationNotMet ]) do
      raise Capybara::ExpectationNotMet, mensaje unless yield
    end
    assert true
  rescue Capybara::ExpectationNotMet
    flunk mensaje
  end
end
