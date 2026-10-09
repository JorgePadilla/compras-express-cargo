require "application_system_test_case"

# El aire de arriba de cada pantalla, medido en Chrome.
#
# Jorge, 2026-10-08: *"I feel that all the pages the empty space on the top is
# too big, we could reduce around probably 60%"*. El título arrancaba a ~88 px:
# un renglón entero para el sol del tema (16 de aire + 36 del botón) y después
# los 32 del contenido. Ahora el sol flota en la esquina, sin renglón, y el
# contenido arranca a 36. Se mide la posición, no la clase: la regresión es un renglón
# que vuelve a aparecer arriba, y eso solo lo dice el navegador.
class MenosAireArribaTest < ApplicationSystemTestCase
  setup { ingresar(users(:admin)) }

  # Con margen: 32 de padding + lo que el navegador redondee. Antes eran ~88.
  TOPE = 44

  test "el título de una pantalla arranca cerca del borde de arriba" do
    visit paquetes_path
    assert_selector "h1", wait: 5

    arriba = page.evaluate_script("document.querySelector('main h1').getBoundingClientRect().top")
    assert_operator arriba, :<=, TOPE, "el título arranca a #{arriba} px del borde"
  end

  test "el Home también: la tarjeta de bienvenida arranca cerca del borde" do
    visit root_path
    assert_selector "main h1, main h2", wait: 5

    arriba = page.evaluate_script(<<~JS)
      (function () {
        var contenido = document.querySelector("main > div.flex-1");
        return contenido.firstElementChild.getBoundingClientRect().top;
      })()
    JS
    assert_operator arriba, :<=, TOPE, "el Home arranca a #{arriba} px del borde"
  end

  # Jorge, después de PR-C29.15: *"me parece que el sol estaba bien arriba"*.
  # Vuelve a la esquina de arriba a la derecha, flotando: ni renglón propio
  # (los dos tests de arriba) ni encima del título o de la tarjeta del Home.
  test "el sol está arriba a la derecha, no se monta sobre nada, y cambia el tema" do
    [ paquetes_path, root_path ].each do |ruta|
      visit ruta
      assert_selector "main h1, main h2", wait: 5
      assert_no_selector "aside#sidebar [data-controller=theme]", visible: :all

      choque = page.evaluate_script(<<~JS)
        (function () {
          var sol = document.querySelector("main > div.absolute [data-controller=theme] button").getBoundingClientRect();
          var primero = document.querySelector("main > div.flex-1").firstElementChild.getBoundingClientRect();
          var main = document.querySelector("main").getBoundingClientRect();
          return { arriba: sol.top - main.top, derecha: main.right - sol.right,
                   pisa: sol.bottom > primero.top && sol.left < primero.right && sol.right > primero.left };
        })()
      JS
      assert_operator choque["arriba"], :<=, 8, "#{ruta}: el sol no está arriba (#{choque['arriba']} px)"
      assert_operator choque["derecha"], :<=, 40, "#{ruta}: el sol no está a la derecha (#{choque['derecha']} px)"
      assert_not choque["pisa"], "#{ruta}: el sol se monta sobre lo primero de la pantalla"
    end

    oscuro_antes = page.evaluate_script("document.documentElement.classList.contains('dark')")
    find("main [data-controller=theme] button").click
    assert_not_equal oscuro_antes, page.evaluate_script("document.documentElement.classList.contains('dark')"),
                     "apretar el sol no cambió el tema"
  end
end
