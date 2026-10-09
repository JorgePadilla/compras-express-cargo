require "application_system_test_case"

# PR-C7.37: entrar al portal tecleando el **código de casillero**.
#
# Yusef, 2026-08-19, dos veces seguidas sobre por qué el correo no le sirve a su
# gente: *"es que mi correo está lleno"*, *"es que yo no tengo correo"*. Y antes:
# *"yo quería que los clientes tengan acceso por su código de cliente"*.
#
# `Cliente.autenticar` acepta código o correo desde `PR-C7.33` y tiene sus tests
# —pero postean directo al controller—. La pantalla lo bloqueaba: el campo era un
# `email_field` con `required`, o sea `<input type="email" required>`, y el
# navegador rechaza `CEC-001` **antes** de enviar el formulario. El modelo decía
# que sí y la pantalla no dejaba llegar.
#
# Por eso este va como system test y no como test de integración: la validación
# que rompía esto es del navegador, y ningún `post` la puede ver.
class LoginConCodigoTest < ApplicationSystemTestCase
  test "el cliente entra con su codigo de casillero" do
    cliente = clientes(:juan)

    visit new_session_path
    fill_in "email_address", with: cliente.codigo
    fill_in "password", with: "Cliente123!"
    click_on "Iniciar Sesion"

    assert_current_path cuenta_root_path, wait: 5
  end

  test "y con su correo, como siempre" do
    cliente = clientes(:juan)

    visit new_session_path
    fill_in "email_address", with: cliente.email
    fill_in "password", with: "Cliente123!"
    click_on "Iniciar Sesion"

    assert_current_path cuenta_root_path, wait: 5
  end

  test "el campo no es type=email, que es lo que bloqueaba el codigo" do
    visit new_session_path

    campo = find("#email_address")
    assert_not_equal "email", campo[:type],
                     "con type=email el navegador rechaza el codigo antes de enviar"
  end

  test "el empleado sigue entrando con su correo" do
    visit new_session_path
    fill_in "email_address", with: users(:admin).email_address
    fill_in "password", with: "password123"
    click_on "Iniciar Sesion"

    assert_no_current_path new_session_path, wait: 5
  end
end
