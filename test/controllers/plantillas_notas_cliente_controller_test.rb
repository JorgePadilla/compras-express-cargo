require "test_helper"

class PlantillasNotasClienteControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    post session_url, params: { email_address: @admin.email_address, password: "password123" }
    @plantilla = PlantillaNotaCliente.create!(titulo: "Test setup", texto: "x")
  end

  test "index responde 200 para admin" do
    get plantillas_notas_cliente_url
    assert_response :success
  end

  test "non-admin queda redirigido" do
    delete session_url
    cajero = users(:cajero)
    post session_url, params: { email_address: cajero.email_address, password: "password123" }
    get plantillas_notas_cliente_url
    assert_redirected_to root_path
  end

  test "new responde 200" do
    get new_plantilla_nota_cliente_url
    assert_response :success
  end

  test "create válido" do
    assert_difference "PlantillaNotaCliente.count", 1 do
      post plantillas_notas_cliente_url,
           params: { plantilla_nota_cliente: { titulo: "Caja golpeada", texto: "Llegó con daño…", activo: true } }
    end
    assert_redirected_to plantillas_notas_cliente_url
  end

  test "create rechaza sin titulo" do
    assert_no_difference "PlantillaNotaCliente.count" do
      post plantillas_notas_cliente_url,
           params: { plantilla_nota_cliente: { titulo: "", texto: "x" } }
    end
    assert_response :unprocessable_entity
  end

  test "edit responde 200" do
    get edit_plantilla_nota_cliente_url(@plantilla)
    assert_response :success
  end

  test "update cambia atributos" do
    patch plantilla_nota_cliente_url(@plantilla),
          params: { plantilla_nota_cliente: { titulo: "Otro", texto: "y", activo: false } }
    assert_redirected_to plantillas_notas_cliente_url
    @plantilla.reload
    assert_equal "Otro", @plantilla.titulo
    assert_not @plantilla.activo
  end
end
