require "application_system_test_case"

# PR-A11Y.5 · Los avisos se le dicen al lector de pantalla, y los errores no se
# van antes de poder leerlos.
#
# Se prueba con un aviso armado en la página porque el mecanismo es el mismo
# en las trece que lo usan (el flash de /etiquetar, la pistola del manifiesto,
# /medicion, recibir carga…): un `data-controller="anuncia-cambios"` que pasa
# lo que entra a las regiones fijas del layout.
class AvisosQueSeEscuchanTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:admin))
    visit proveedores_path
    page.execute_script(<<~JS)
      const aviso = document.createElement("div")
      aviso.id = "aviso-de-prueba"
      aviso.dataset.controller = "anuncia-cambios"
      document.querySelector("main").prepend(aviso)
    JS
    assert_selector "#aviso-de-prueba[data-controller]", visible: :all
    # Stimulus conecta en el próximo tick.
    page.evaluate_script("new Promise(r => setTimeout(r, 100))")
  end

  test "lo que entra a un aviso se le dice al lector" do
    page.execute_script("document.getElementById('aviso-de-prueba').textContent = 'Paquete agregado al manifiesto'")

    assert_eventualmente("no se anunció") { region("aviso-lector") == "Paquete agregado al manifiesto" }
  end

  test "un flash de error va a la región urgente" do
    meter_flash("alert", "El tracking ya existe")

    assert_eventualmente("el error no fue urgente") { region("aviso-lector-urgente") == "El tracking ya existe" }
  end

  test "sacar un flash viejo no vuelve a anunciar nada" do
    meter_flash("notice", "Guardado")
    assert_eventualmente("no se anunció") { region("aviso-lector") == "Guardado" }
    page.execute_script("document.getElementById('aviso-lector').textContent = ''")

    page.execute_script("document.querySelector('#aviso-de-prueba [data-flash]').remove()")
    page.evaluate_script("new Promise(r => setTimeout(r, 200))")

    assert_equal "", region("aviso-lector")
  end

  test "un aviso con el mouse encima no se va" do
    page.execute_script(<<~JS)
      const f = document.createElement("div")
      f.id = "flash-que-espera"
      f.textContent = "Leeme despacio"
      f.dataset.controller = "auto-dismiss"
      f.dataset.autoDismissDelayValue = "400"
      document.querySelector("main").prepend(f)
    JS
    find("#flash-que-espera").hover

    page.evaluate_script("new Promise(r => setTimeout(r, 900))")
    assert_selector "#flash-que-espera"

    find("h1").hover
    assert_no_selector "#flash-que-espera", wait: 3
  end

  private

  def meter_flash(tipo, texto)
    page.execute_script(<<~JS, tipo, texto)
      const f = document.createElement("div")
      f.dataset.flash = arguments[0]
      f.textContent = arguments[1]
      document.getElementById("aviso-de-prueba").prepend(f)
    JS
  end

  def region(id)
    page.evaluate_script("document.getElementById('#{id}').textContent")
  end
end
