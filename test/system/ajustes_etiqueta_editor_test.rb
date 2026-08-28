require "application_system_test_case"

# C19-06 · PR-C7.64: el preview en vivo del editor de la etiqueta.
#
# El estado «Cabe / Se recorta» mide en el iframe exactamente lo que mide
# etiqueta_cabe_test: scrollHeight vs clientHeight del .etq — así lo que
# Yusef ve al ajustar es lo mismo que vigila la suite con el default.
class AjustesEtiquetaEditorTest < ApplicationSystemTestCase
  setup do
    visit new_session_path
    fill_in "email_address", with: users(:admin).email_address, wait: 10
    fill_in "password", with: "password123"
    click_on "Iniciar Sesion"
    assert_no_current_path new_session_path, wait: 8

    visit ajustes_etiqueta_path
    assert_selector "[data-etiqueta-editor-target='iframe']", wait: 5
  end

  test "el preview carga, mide, y reacciona a la escala" do
    # El primer render de la muestra: cabe (es la etiqueta de fábrica).
    assert_selector "[data-etiqueta-editor-target='estado']", text: "Cabe ✓", wait: 10

    # Mover la escala re-renderiza el preview con las vars nuevas.
    page.execute_script(<<~JS)
      const rango = document.querySelector("[data-def-path='escala_pct']")
      rango.value = 110
      rango.dispatchEvent(new Event("input", { bubbles: true }))
    JS

    esperar { page.evaluate_script(srcdoc_js).to_s.include?("--fs-tipo-envio: 20.9pt") }
    assert_includes page.evaluate_script(srcdoc_js).to_s, "--fs-tipo-envio: 20.9pt",
                    "el preview no re-renderizó con la escala nueva"

    # Y el efectivo del campo lo dice en la pantalla.
    assert_selector "[data-para-path='campos.tipo_envio.pt']", text: "20.9pt"
  end

  test "achicar el alto enciende el «se recorta»" do
    assert_selector "[data-etiqueta-editor-target='estado']", text: "Cabe ✓", wait: 10

    page.execute_script(<<~JS)
      const alto = document.querySelector("[data-def-path='dim.alto_in']")
      alto.value = "1.0"
      alto.dispatchEvent(new Event("input", { bubbles: true }))
    JS

    assert_selector "[data-etiqueta-editor-target='estado']", text: /Se recortan \d+px/, wait: 10
  end

  private

  def srcdoc_js
    "document.querySelector(\"[data-etiqueta-editor-target='iframe']\").getAttribute('srcdoc')"
  end

  def esperar(segundos: 10)
    limite = Process.clock_gettime(Process::CLOCK_MONOTONIC) + segundos
    sleep 0.15 until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > limite
  end
end
