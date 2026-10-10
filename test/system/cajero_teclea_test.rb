require "application_system_test_case"

# PR-C30.9 · Que el cajero pueda teclear en un system test.
#
# El par `cajero@test.com` + `password123` está en la lista de credenciales
# filtradas de Chrome: al loguearse, el navegador abre su aviso «cambiá tu
# contraseña» y ese aviso se queda con el teclado. Sin el flag de
# `ApplicationSystemTestCase` (`SIN_AVISO_DE_CONTRASENA_FILTRADA`) ninguna
# tecla de WebDriver llega a la página, en ninguna pantalla — y el que recibe
# carga (C21-07) es justamente un rol que hay que poder probar con pistola.
class CajeroTecleaTest < ApplicationSystemTestCase
  test "el cajero escribe en la pistola de recibir carga" do
    manifiesto = manifiestos(:enviado)
    ingresar(users(:cajero))

    visit recepcion_carga_path(manifiesto)
    # El aviso no sale en el acto: Chrome consulta la lista de filtradas por
    # la red y lo abre cuando vuelve la respuesta. Tecleando enseguida, el
    # test pasaba **con el bug puesto** — se comprobó sacando el flag. Ese
    # aviso es del navegador, no de la página, así que no hay nada en el DOM
    # que esperar: se espera el tiempo, y por eso es un `sleep`.
    sleep 2
    find("#codigo_caja").send_keys("ABC-123")

    assert_equal "ABC-123", find("#codigo_caja").value,
                 "las teclas no llegaron: ¿volvió el aviso de contraseña filtrada de Chrome?"
  end
end
