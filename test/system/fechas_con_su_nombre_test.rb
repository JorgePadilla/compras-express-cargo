require "application_system_test_case"

# PR-A11Y.6 · La fecha que se ve es la que lleva el nombre, y lo que el campo
# sabía.
#
# Con `altInput`, flatpickr esconde el input real y crea otro visible. El
# visible ya tomaba el rótulo (PR-C32.8); le faltaba `aria-required` y la
# ayuda que lo describe. El de volver con el caché de Turbo pasaba ya antes:
# queda como red, porque el rótulo se reapunta a mano.
class FechasConSuNombreTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:admin))
  end

  test "la fecha visible es obligatoria si el campo lo era, y el rótulo la nombra" do
    visit new_feriado_path

    visible = fecha_visible
    assert visible[:required], "la fecha visible no quedó obligatoria"
    assert_equal "true", visible["aria-required"]
    assert_equal visible[:id], find("label", text: /Fecha/)[:for]
  end

  test "al volver con el caché de Turbo la fecha sigue con su nombre, y hay una sola" do
    visit new_feriado_path
    fecha_visible
    visit proveedores_path
    assert_selector "h1", text: "Proveedores"

    page.go_back

    assert_selector "input[name='feriado[fecha]']", visible: :all, wait: 5
    visibles = all("input.flatpickr-input, input.form-control", visible: true).select { |i| i[:name].blank? }
    assert_equal 1, visibles.size, "quedaron #{visibles.size} fechas visibles"
    assert_equal visibles.first[:id], find("label", text: /Fecha/)[:for]
  end

  private

  def fecha_visible
    assert_selector "input[name='feriado[fecha]']", visible: :all, wait: 5
    find("#feriado_fecha_visible")
  end
end
