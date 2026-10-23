require "application_system_test_case"

# PR-A11Y.4 · Los autocompletes, para un lector de pantalla.
#
# El teclado andaba en los ocho (flechas, Enter, Tab, Escape), pero no había
# ni un `role`: la fila activa era solo un fondo teal, y con las flechas no se
# oía nada. Es la base compartida (`busqueda_autocomplete.js`), así que se
# prueba en uno: el buscador de cliente de /pre_alertas/new.
class AutocompleteAccesibleTest < ApplicationSystemTestCase
  CAMPO = "[data-client-autocomplete-target=input]".freeze

  setup do
    ingresar(users(:admin))
    visit new_pre_alerta_path
    assert_selector CAMPO, wait: 5
  end

  test "el campo es un combobox que dice si la lista está abierta" do
    find(CAMPO).set("2")
    assert_selector "[role=option]", wait: 5

    campo = find(CAMPO)
    assert_equal "combobox", campo[:role]
    assert_equal "true", campo["aria-expanded"]
    lista = find("##{campo['aria-controls']}", visible: :all)
    assert_equal "listbox", lista[:role]

    campo.send_keys(:escape)
    assert_equal "false", find(CAMPO)["aria-expanded"]
  end

  test "las flechas mueven la opción activa, y el campo la anuncia" do
    find(CAMPO).set("CEC")
    assert_selector "[role=option]", minimum: 2, wait: 5

    opciones = all("[role=option]")
    assert_equal opciones[0][:id], find(CAMPO)["aria-activedescendant"]
    assert_equal "true", opciones[0]["aria-selected"]

    find(CAMPO).send_keys(:down)

    assert_eventualmente("la activa no pasó a la segunda") do
      find(CAMPO)["aria-activedescendant"] == opciones[1][:id]
    end
    assert_equal "true", all("[role=option]")[1]["aria-selected"]
    assert_equal "false", all("[role=option]")[0]["aria-selected"]
  end

  test "dice cuántos resultados hay, y cuando no hay ninguno" do
    find(CAMPO).set("2")
    assert_selector "[role=option]", wait: 5
    assert_eventualmente("no anunció los resultados") { aviso =~ /\A\d+ resultados?\z/ }

    find(CAMPO).set("zzzz-no-existe")
    assert_eventualmente("no anunció que no hay") { aviso == "No se encontraron clientes" }
  end

  private

  def aviso
    page.evaluate_script("document.getElementById('aviso-lector')?.textContent")
  end
end
