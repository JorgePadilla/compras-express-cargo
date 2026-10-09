require "application_system_test_case"

# El aire de arriba de cada pantalla, medido en Chrome.
#
# Jorge, 2026-10-08: *"I feel that all the pages the empty space on the top is
# too big, we could reduce around probably 60%"*. El título arrancaba a ~88 px:
# un renglón entero para el sol del tema (16 de aire + 36 del botón) y después
# los 32 del contenido. El sol se fue al pie de la barra lateral y el título
# arranca a 32. Se mide la posición, no la clase: la regresión es un renglón
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

  test "el sol del tema vive en el pie de la barra, y cambia el tema" do
    visit paquetes_path
    assert_no_selector "main > div [data-controller=theme]", visible: :all,
                       wait: 0
    boton = find("aside#sidebar [data-controller=theme] button", visible: :all)

    oscuro_antes = page.evaluate_script("document.documentElement.classList.contains('dark')")
    page.execute_script("arguments[0].click()", boton)
    oscuro_despues = page.evaluate_script("document.documentElement.classList.contains('dark')")
    assert_not_equal oscuro_antes, oscuro_despues, "apretar el sol de la barra no cambió el tema"
  end
end
