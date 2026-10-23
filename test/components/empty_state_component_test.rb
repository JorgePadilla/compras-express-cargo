require "test_helper"

# PR-A11Y.2 · El estado vacío iba con `h3` fijo, justo debajo del `h1` de
# PageHeaderComponent: el lector de pantalla saltaba del 1 al 3.
class EmptyStateComponentTest < ViewComponent::TestCase
  test "el título es h2 por defecto" do
    render_inline(EmptyStateComponent.new(title: "No hay paquetes"))

    assert_selector "h2", text: "No hay paquetes"
    assert_no_selector "h3"
  end

  test "adentro de una sección se le pide h3" do
    render_inline(EmptyStateComponent.new(title: "Sin notas", titulo_tag: :h3))

    assert_selector "h3", text: "Sin notas"
  end

  test "el ícono es decorativo" do
    render_inline(EmptyStateComponent.new(title: "Vacío"))

    assert_selector "svg[aria-hidden='true']"
  end
end
