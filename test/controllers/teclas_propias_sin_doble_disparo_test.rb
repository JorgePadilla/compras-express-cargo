require "test_helper"

# C30-02 · F8 guarda aunque el foco esté en un campo (`keyboard_shortcuts`).
#
# Las pantallas que escuchan F8 **ellas mismas** —/etiquetar, Medición y el
# editor de pre-alertas, en admin y en el portal— no pueden tener además un
# botón con `data-shortcut="F8"`: el atajo global le haría click y la pantalla
# guardaría dos veces. Hasta acá eso lo cuidaba de rebote la regla de «no
# disparar mientras se escribe», que justamente es lo que se acaba de abrir
# para F8. Sus botones van con `shortcut_label_only`: el rótulo sin el atributo.
class TeclasPropiasSinDobleDisparoTest < ActionDispatch::IntegrationTest
  test "/etiquetar" do
    ingresar(users(:digitador))
    post iniciar_sesion_etiquetar_url, params: { tipo_envio_id: tipo_envios(:cer).id }
    get etiquetar_url

    assert_escucha_f8_sin_atributo("etiquetar")
  end

  test "Medición" do
    ingresar(users(:medidor))
    get medicion_index_url

    assert_escucha_f8_sin_atributo("medicion")
  end

  test "el editor de pre-alertas de admin" do
    ingresar(users(:admin))
    get edit_pre_alerta_url(pre_alertas(:activa))

    assert_escucha_f8_sin_atributo("pre-alerta-editor")
  end

  test "y su gemela del portal" do
    post session_url, params: { email_address: clientes(:juan).email, password: "Cliente123!" }
    get edit_cuenta_pre_alerta_url(pre_alertas(:activa))

    assert_escucha_f8_sin_atributo("pre-alerta-editor")
  end

  private

  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def assert_escucha_f8_sin_atributo(controller)
    assert_response :success
    assert_select "[data-controller~='#{controller}']", { minimum: 1 },
                  "la pantalla no monta #{controller}: este test no prueba nada"
    assert_select "[data-shortcut='F8']", 0,
                  "#{controller} escucha F8 solo: un data-shortcut=\"F8\" acá guardaría dos veces"
  end
end
