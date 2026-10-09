require "application_system_test_case"

# «Sonidos» va debajo del sol, en la esquina de arriba a la derecha.
#
# Jorge, 2026-10-09: *"me parece que el botón de sonido va mejor debajo del sol
# en mediciones, y si hay en otras partes también"*. Está en las cinco
# pantallas de escaneo (/etiquetar, /entrega_personal, el manifiesto, /empacar
# y /medicion); acá se miden dos, con lo que el navegador pinta: debajo del
# sol, alineado a la derecha, y sin pisar el título ni el subtítulo.
class SonidosBajoElSolTest < ApplicationSystemTestCase
  teardown { page.driver.browser.manage.window.resize_to(1400, 1400) }

  # 1024: el subtítulo de /medicion se parte en dos renglones y llega hasta
  # la derecha; es el caso que pisaría «Sonidos» sin el lugar que le deja el
  # encabezado.
  [ 1024, 1400 ].each do |ancho|
    test "en /medicion a #{ancho} px «Sonidos» está debajo del sol y no pisa el título" do
      page.driver.browser.manage.window.resize_to(ancho, 900)
      ingresar(users(:medidor))
      visit medicion_index_path
      assert_bajo_el_sol
    end
  end

  test "en el manifiesto también" do
    ingresar(users(:admin))
    visit manifiesto_path(manifiestos(:creado))
    assert_bajo_el_sol
  end

  private

  def assert_bajo_el_sol
    assert_selector "h1", wait: 5
    m = page.evaluate_script(<<~JS)
      (function () {
        var esquina = document.querySelector("main > div.absolute");
        var sol = esquina.querySelector("[data-controller=theme] button").getBoundingClientRect();
        var son = esquina.querySelector("[data-controller=sonido-config] button").getBoundingClientRect();
        var titulo = document.querySelector("main h1").parentElement.getBoundingClientRect();
        var textos = Array.from(document.querySelectorAll("main h1, main h1 + p")).map(function (e) {
          var r = e.ownerDocument.createRange(); r.selectNodeContents(e); return r.getBoundingClientRect();
        });
        var pisa = textos.some(function (t) { return t.right > son.left && t.left < son.right && t.bottom > son.top && t.top < son.bottom; });
        return { debajo: son.top >= sol.bottom, derecha: Math.abs(son.right - sol.right), pisa: pisa };
      })()
    JS
    assert m["debajo"], "«Sonidos» no está debajo del sol"
    assert_operator m["derecha"], :<=, 2, "«Sonidos» no está alineado a la derecha con el sol"
    assert_not m["pisa"], "«Sonidos» se monta sobre el título o el subtítulo"
  end
end
