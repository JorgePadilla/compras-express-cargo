require "test_helper"

# C19-04. Yusef: "si aquí en la descripción del contenido les podemos poner un
# check nada más que diga sellado… hay dos cosas: sellado y compra chino, son
# más comunes". Catálogo CRUD calcado de PlantillaNotaCliente.
class PlantillasDescripcionControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    post session_url, params: { email_address: @admin.email_address, password: "password123" }
    @plantilla = PlantillaDescripcion.create!(titulo: "Test setup", texto: "x")
  end

  test "index responde 200 para admin" do
    get plantillas_descripcion_url
    assert_response :success
  end

  test "non-admin queda redirigido" do
    delete session_url
    cajero = users(:cajero)
    post session_url, params: { email_address: cajero.email_address, password: "password123" }
    get plantillas_descripcion_url
    assert_redirected_to root_path
  end

  test "new responde 200" do
    get new_plantilla_descripcion_url
    assert_response :success
  end

  test "create válido" do
    assert_difference "PlantillaDescripcion.count", 1 do
      post plantillas_descripcion_url,
           params: { plantilla_descripcion: { titulo: "Sellado", texto: "Sellado", activo: true } }
    end
    assert_redirected_to plantillas_descripcion_url
  end

  test "create rechaza sin titulo" do
    assert_no_difference "PlantillaDescripcion.count" do
      post plantillas_descripcion_url,
           params: { plantilla_descripcion: { titulo: "", texto: "x" } }
    end
    assert_response :unprocessable_entity
  end

  test "edit responde 200" do
    get edit_plantilla_descripcion_url(@plantilla)
    assert_response :success
  end

  test "update cambia atributos" do
    patch plantilla_descripcion_url(@plantilla),
          params: { plantilla_descripcion: { titulo: "Otro", texto: "y", activo: false } }
    assert_redirected_to plantillas_descripcion_url
    @plantilla.reload
    assert_equal "Otro", @plantilla.titulo
    assert_not @plantilla.activo
  end

  # La lección repetida del repo: el arreglo que llega a una pantalla y no a
  # su gemela. Los chips van en las TRES pantallas que editan la descripción.
  test "los chips salen en las tres gemelas" do
    PlantillaDescripcion.create!(titulo: "Sellado", texto: "Sellado")

    delete session_url
    digitador = users(:digitador)
    post session_url, params: { email_address: digitador.email_address, password: "password123" }

    # La firma inequívoca del partial: el picker apuntando a la descripción.
    # ("plantilla-picker" a secas no alcanza — el form de /paquetes ya trae el
    # de notas al cliente.)
    firma = 'data-plantilla-picker-target-selector-value="#paquete_descripcion"'

    # /etiquetar (la sesión de tipo de envío puede estar pedida o no)
    get etiquetar_url
    if response.body.include?("¿Qué tipo de envío vas a trabajar?")
      post iniciar_sesion_etiquetar_url, params: { tipo_envio_id: TipoEnvio.activos.first.id }
      follow_redirect!
    end
    assert_match firma, response.body, "los chips no salieron en /etiquetar"

    # /entrega_personal
    get new_entrega_personal_url
    assert_match firma, response.body, "los chips no salieron en /entrega_personal"

    # El form de /paquetes (modo edición, con un rol que edita)
    delete session_url
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
    get paquete_url(paquetes(:disponible_entrega_juan), mode: "edit")
    assert_match firma, response.body, "los chips no salieron en el form de /paquetes"
  end
end
