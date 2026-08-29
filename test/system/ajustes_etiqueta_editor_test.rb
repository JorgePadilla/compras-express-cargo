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

  test "apagar un campo y cambiar un rotulo se ven en el preview" do
    assert_selector "[data-etiqueta-editor-target='estado']", text: "Cabe ✓", wait: 10
    esperar { page.evaluate_script(srcdoc_js).to_s.include?('data-campo="tercero"') }

    page.execute_script(%(document.querySelector("[data-def-path='campos.tercero.visible']").click()))
    esperar { !page.evaluate_script(srcdoc_js).to_s.include?('data-campo="tercero"') }
    assert_not_includes page.evaluate_script(srcdoc_js).to_s, 'data-campo="tercero"',
                        "el tercero apagado siguió saliendo en el preview"

    page.execute_script(<<~JS)
      const texto = document.querySelector("[data-def-path='campos.sucursal.texto']")
      texto.value = "AGENCIA"
      texto.dispatchEvent(new Event("input", { bubbles: true }))
    JS
    esperar { page.evaluate_script(srcdoc_js).to_s.include?("AGENCIA") }
    assert_includes page.evaluate_script(srcdoc_js).to_s, "AGENCIA"
  end

  test "las flechas reordenan y el preview lo muestra" do
    assert_selector "[data-etiqueta-editor-target='estado']", text: "Cabe ✓", wait: 10
    esperar { page.evaluate_script(srcdoc_js).to_s.include?("data-campo") }

    # De fábrica el número va antes que el tracking; la flecha lo invierte.
    antes = page.evaluate_script(srcdoc_js).to_s
    assert_operator antes.index('data-campo="numero-recepcion"'), :<, antes.index('data-campo="tracking"')

    find("[data-fila-id='f-tracking'] button[title='Subir la fila']").click

    esperar do
      doc = page.evaluate_script(srcdoc_js).to_s
      t = doc.index('data-campo="tracking"')
      n = doc.index('data-campo="numero-recepcion"')
      t && n && t < n
    end
    despues = page.evaluate_script(srcdoc_js).to_s
    assert_operator despues.index('data-campo="tracking"'), :<, despues.index('data-campo="numero-recepcion"'),
                    "el preview no reflejó el orden nuevo"
  end

  test "elegir la alineacion del barcode se ve en el preview" do
    # C20-02: los cuatro radios comparten `data-def-path`; sin el guard de
    # `checked` en el serializer gana el último y se guarda cualquier cosa.
    assert_selector "[data-etiqueta-editor-target='estado']", text: "Cabe ✓", wait: 10
    esperar { page.evaluate_script(srcdoc_js).to_s.include?('data-alineacion="justificado"') }

    page.execute_script(%(document.querySelector("input[name='barcode_alineacion'][value='centro']").click()))

    esperar { page.evaluate_script(srcdoc_js).to_s.include?('data-alineacion="centro"') }
    doc = page.evaluate_script(srcdoc_js).to_s
    assert_includes doc, "justify-content:center"
    assert_includes doc, 'data-alineacion="centro"'

    json = JSON.parse(page.evaluate_script("document.querySelector(\"[data-etiqueta-editor-target='json']\").value"))
    assert_equal "centro", json.dig("campos", "barcode", "alineacion"),
                 "el serializer mandó el radio equivocado"
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
