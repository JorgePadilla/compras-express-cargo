require "test_helper"

# C18-06: el catálogo lo administra un admin, como el de retención.
class MotivosEnvioPoliticaControllerTest < ActionDispatch::IntegrationTest
  def entrar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  test "admin ve el index y crea" do
    entrar users(:admin)

    get motivos_envio_politica_url
    assert_response :success
    assert_match(/Sin pre-alerta ni identificación/, response.body)

    assert_difference("MotivoEnvioPolitica.count") do
      post motivos_envio_politica_url, params: { motivo_envio_politica: { nombre: "Nombre a medias",
                                                                          texto_al_cliente: "Solo se leía el nombre.",
                                                                          position: 3, activo: "1" } }
    end
    assert_redirected_to motivos_envio_politica_path
  end

  test "sin texto al cliente no se crea: es lo que le llega" do
    entrar users(:admin)

    assert_no_difference("MotivoEnvioPolitica.count") do
      post motivos_envio_politica_url, params: { motivo_envio_politica: { nombre: "Sin texto", texto_al_cliente: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "el digitador no entra" do
    entrar users(:digitador)

    get motivos_envio_politica_url
    assert_redirected_to root_path
  end

  test "esta en el menu y en el dashboard" do
    entrar users(:admin)
    get root_url
    assert_match %r{href="#{motivos_envio_politica_path}"}, response.body
  end
end
