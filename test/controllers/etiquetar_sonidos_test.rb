require "test_helper"

# PR-C6.16: los sonidos de /etiquetar, completos.
#
# Yusef describió cuatro avisos distintos a lo largo de la reunión, y la razón
# no es cosmética:
#
#   "Ahorita el sistema es bolazón, pero más adelante pueda que tenga un
#    pequeño lag de milisegundos... **ocupamos la confirmación** para que ellos
#    puedan estar seguros de que pueden seguir."
#
# En Miami trabajan con las manos y no miran la pantalla todo el tiempo.
#
# Este test fija el **cableado**, que es lo verificable sin un navegador: que
# cada evento tenga su sonido. Cómo suena cada uno es cosa de Yusef — el pin
# que ya existía lo aprobó ("se oye amigable, no se oye así como que lo querés
# apagar"), y las grabaciones de voz para pre-alerta las manda él.
class EtiquetarSonidosTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: tipo_envios(:cer).id, sucursal_recepcion_id: sucursales(:miami).id }
    get etiquetar_url
    @body = response.body
  end

  test "el paquete guardado suena" do
    assert_match(/etiquetar:success->audio#success/, @body)
  end

  test "la pre-alerta tiene su aviso propio" do
    # "Pita para dos razones... pita, te decía, pre-alerta."
    assert_match(/etiquetar:preAlertaMatch->audio#speakPreAlerta/, @body)
  end

  test "el tracking que ya existia tiene OTRO aviso" do
    # "El otro pito es porque te tira que **ya existía**." Son dos, no uno.
    assert_match(/etiquetar:trackingYaExiste->audio#notify/, @body)
  end

  test "el tipo de envio equivocado suena feo" do
    # El único que usa `error`: "y el feo es cuando hay un error como el de que
    # tiene diferentes tipos de envío".
    assert_match(/etiquetar:tipoEnvioDistinto->audio#error/, @body)
  end

  test "hay un pin antes de que salga el modal" do
    # "Aquí debería de ser otro PIN cuando tires el modal... ese PIN lo ocupo
    # ANTES más bien, en el modal."
    assert_match(/etiquetar:modalAbierto->audio#notify/, @body)
  end

  test "estan cableados los seis eventos" do
    metodos = @body.scan(/etiquetar:(\w+)->audio#(\w+)/).to_h

    assert_equal %w[success clienteNotas preAlertaMatch trackingYaExiste modalAbierto tipoEnvioDistinto].sort,
                 metodos.keys.sort,
                 "faltó cablear algún evento de sonido"
  end

  test "los avisos que tienen que distinguirse no se pisan" do
    # Pre-alerta, "ya existía" y error son tres cosas distintas que el operario
    # tiene que poder separar de oído sin mirar la pantalla.
    metodos = @body.scan(/etiquetar:(\w+)->audio#(\w+)/).to_h

    distintos = metodos.values_at("preAlertaMatch", "trackingYaExiste", "tipoEnvioDistinto")
    assert_equal 3, distintos.uniq.size, "dos avisos suenan igual: #{distintos.inspect}"
  end
end
