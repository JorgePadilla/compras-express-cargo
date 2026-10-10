require "application_system_test_case"

# PR-C30.10 · Cancelar «¿Cuántas etiquetas?» con el mouse devuelve el teclado
# al campo donde estaba el operario.
#
# El bug que midió C30-10 en Chrome: cerrar un `<dialog>` con el mouse o el
# dedo deja al campo con cara de enfocado —`document.activeElement` lo
# nombra— y lo que se teclea **no entra**. Con Enter no pasa, y por eso un test
# que cierra con Enter da verde con el bug puesto. Este cierra con clic y
# después **escribe**: lo que se afirma es dónde cayeron las letras.
class EntregaPersonalFocoAlCancelarTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))
    visit new_entrega_personal_path
    assert_selector "form", wait: 5
  end

  test "cancelar con clic y seguir escribiendo en el remitente" do
    find("#paquete_descripcion").set("Ropa")
    find("#paquete_remitente").click
    find("#paquete_remitente").send_keys("Wal")

    find("button", text: "Guardar + Imprimir", match: :first).click
    assert_selector "[data-entrega-personal-target='etiquetasModal'][open]", wait: 3

    within("[data-entrega-personal-target='etiquetasModal']") { click_on "Cancelar" }
    assert_no_selector "[data-entrega-personal-target='etiquetasModal'][open]", wait: 3

    assert_eventualmente("el foco no volvió al remitente") do
      page.evaluate_script("document.activeElement && document.activeElement.id") == "paquete_remitente"
    end
    page.driver.browser.action.send_keys("mart").perform

    assert_eventualmente("lo tecleado no entró al remitente") { find("#paquete_remitente").value == "Walmart" }
  end

  test "con Escape vuelve igual" do
    find("#paquete_descripcion").set("Ropa")
    find("#paquete_remitente").click

    page.driver.browser.action.send_keys(:f9).perform
    assert_selector "[data-entrega-personal-target='etiquetasModal'][open]", wait: 3
    page.driver.browser.action.send_keys(:escape).perform
    assert_no_selector "[data-entrega-personal-target='etiquetasModal'][open]", wait: 3

    page.driver.browser.action.send_keys("Amazon").perform
    assert_eventualmente("lo tecleado no entró al remitente") { find("#paquete_remitente").value == "Amazon" }
  end
end
