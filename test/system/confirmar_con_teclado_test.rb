require "application_system_test_case"

# PR-A11Y.1 · El «Confirmar» compartido (`shared/_confirm_modal`) con el
# teclado solo.
#
# Abre con el foco en «Cancelar», justamente para no confirmar sin querer.
# Pero un listener del documento confirmaba con **cualquier** Enter, así que
# Enter sobre «Cancelar» confirmaba, y el botón de confirmar es rojo por
# defecto. Ahora Enter lo aprieta el botón que tiene el foco.
class ConfirmarConTecladoTest < ApplicationSystemTestCase
  MODAL = "[data-confirm-modal-target='root']".freeze

  setup do
    ingresar(users(:admin))
    visit proveedores_path
  end

  test "Enter con el foco en Cancelar cancela" do
    preguntar
    assert_equal "Cancelar", page.evaluate_script("document.activeElement.textContent.trim()")

    page.driver.browser.action.send_keys(:enter).perform

    assert_equal false, respuesta
  end

  test "Tab pasa a Confirmar, y ahí Enter confirma" do
    preguntar
    page.driver.browser.action.send_keys(:tab).perform
    assert_equal "Confirmar", page.evaluate_script("document.activeElement.textContent.trim()")

    page.driver.browser.action.send_keys(:enter).perform

    assert_equal true, respuesta
  end

  test "Tab no se escapa a la página de atrás" do
    preguntar
    page.driver.browser.action.send_keys(:tab, :tab, :tab).perform

    assert page.evaluate_script("document.querySelector(\"#{MODAL}\").contains(document.activeElement)"),
           "el foco salió del modal"
  end

  test "Escape cancela, y el foco vuelve al que lo abrió" do
    page.execute_script(<<~JS)
      const b = document.createElement("button")
      b.id = "abre-confirmar"; b.textContent = "Abrir"
      document.querySelector("main").prepend(b)
      b.focus()
    JS
    preguntar
    page.driver.browser.action.send_keys(:escape).perform

    assert_equal false, respuesta
    assert_equal "abre-confirmar", page.evaluate_script("document.activeElement.id")
  end

  test "el lector de pantalla lo nombra con su título y su pregunta" do
    preguntar
    modal = find(MODAL)

    assert_equal "Borrar", find("##{modal['aria-labelledby']}").text
    assert_equal "¿Seguro que lo borrás?", find("##{modal['aria-describedby']}").text
  end

  private

  def preguntar
    page.execute_script(<<~JS)
      window.__respuesta = undefined
      window.cecConfirm("¿Seguro que lo borrás?", { title: "Borrar" }).then(r => { window.__respuesta = r })
    JS
    assert_selector MODAL, visible: true
    assert_eventualmente("el foco no entró al modal") do
      page.evaluate_script("document.querySelector(\"#{MODAL}\").contains(document.activeElement)")
    end
  end

  def respuesta
    assert_eventualmente("el modal no contestó") { !page.evaluate_script("window.__respuesta").nil? }
    page.evaluate_script("window.__respuesta")
  end
end
