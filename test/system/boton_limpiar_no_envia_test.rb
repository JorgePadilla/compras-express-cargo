require "application_system_test_case"

# PR-BTN.1: el botón "Limpiar" limpia. No guarda.
#
# `ButtonComponent` renderizaba `content_tag :button` **sin `type`**, y HTML
# dice que un `<button>` sin type dentro de un `<form>` es `type="submit"`.
#
# En /entrega_personal eso significaba que "Limpiar" corría
# `entrega-personal#clearForm` —que hace `form.reset()` y no llama a
# `preventDefault`— y **acto seguido el navegador enviaba el formulario**. El
# operario le daba a Limpiar y le salía un error de validación, o peor, se le
# guardaba lo que estaba a medio llenar.
#
# El arreglo es una línea (`type: @type || "button"`), pero es de las que se
# deshacen sin querer, y falla en silencio: el botón se ve idéntico.
class BotonLimpiarNoEnviaTest < ApplicationSystemTestCase
  setup do
    visit new_session_path
    fill_in "email_address", with: users(:digitador).email_address
    fill_in "password", with: "password123"
    click_on "Iniciar Sesion"
    assert_no_current_path new_session_path, wait: 5

    visit new_entrega_personal_path
    assert_selector "[data-entrega-personal-target=clienteInput]", wait: 5
  end

  test "Limpiar no envia el formulario" do
    fill_in "paquete[peso]", with: "12.5"

    antes = Paquete.count
    click_on "Limpiar"

    # El campo se vacia...
    assert_field "paquete[peso]", with: "", wait: 5
    # ...y no se fue nada al servidor. Sigue en la misma pantalla, sin error.
    assert_current_path new_entrega_personal_path
    assert_no_text "no puede estar en blanco"
    assert_equal antes, Paquete.count
  end

  test "el boton dice que es de tipo button" do
    # El assert barato que explica el de arriba cuando falla.
    assert_selector "button[type='button']", text: "Limpiar"
  end
end
