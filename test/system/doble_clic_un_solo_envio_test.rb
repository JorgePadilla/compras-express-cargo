require "application_system_test_case"

# C31-03 · Doble clic, dos registros. Yusef, en la prueba del 2026-10-12: *"Le
# di muy rápido dos veces… y mandó la versión dos veces"*, y en el manifiesto
# aparecieron dos cajas. Un botón que guarda queda trabado al primer clic
# (`controllers/un_solo_envio`), y la tecla sostenida cuenta una vez.
class DobleClicUnSoloEnvioSystemTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))
    @manifiesto = manifiestos(:creado)
    @manifiesto.update!(sucursal_origen: sucursales(:miami))
  end

  test "doble clic en «Agregar caja» arma una sola caja" do
    visit manifiesto_path(@manifiesto)
    find("#caja_manifiesto_peso").set("5")

    find("button", text: "Agregar caja").double_click

    assert_text "Caja A agregada", wait: 5
    assert_no_text "Caja B agregada", wait: 1
    assert_equal 1, @manifiesto.cajas.count
  end

  # El agujero de verdad: va sin Turbo (`data-turbo=false`), así que nadie
  # deshabilita el botón mientras carga la página nueva.
  test "doble clic en «Agregar e imprimir» también arma una sola" do
    visit manifiesto_path(@manifiesto)
    find("#caja_manifiesto_peso").set("5")

    # El segundo clic llega cuando el primer POST ya salió: el navegador
    # cancela esa navegación y arranca otra, pero el servidor ya tiene las dos.
    page.execute_script(<<~JS)
      const boton = [ ...document.querySelectorAll("button") ].find((b) => b.textContent.includes("Agregar e imprimir"))
      boton.click()
      setTimeout(() => boton.click(), 40)
    JS

    assert_current_path(/etiqueta/, wait: 5)
    assert_equal 1, @manifiesto.cajas.count
  end

  # F5 sostenido: el navegador repite el `keydown` con `repeat`, cada ~40 ms.
  # `requestSubmit` no mira si el botón quedó deshabilitado, y Turbo, con un
  # envío nuevo, corta el anterior **después** de que salió.
  test "F5 sostenido arma una sola caja" do
    visit manifiesto_path(@manifiesto)
    find("#caja_manifiesto_peso").set("5")

    page.execute_script(<<~JS)
      const peso = document.getElementById("caja_manifiesto_peso")
      const tecla = (repeat) => peso.dispatchEvent(new KeyboardEvent("keydown", { key: "F5", repeat, bubbles: true }))
      tecla(false)
      setTimeout(() => tecla(true), 40)
      setTimeout(() => tecla(true), 80)
    JS

    assert_text "Caja A agregada", wait: 5
    assert_no_text "Caja B agregada", wait: 1
    assert_equal 1, @manifiesto.cajas.count
  end
end
