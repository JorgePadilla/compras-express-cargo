require "test_helper"

# PR-6a/6b salieron sin ninguna cobertura de request. PR-9.b la agrega ahora
# que la pantalla además monta la franja de contexto.
class EntregaPersonalControllerTest < ActionDispatch::IntegrationTest
  setup do
    login_as users(:digitador)
  end

  def login_as(user)
    delete session_url
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  test "should get new" do
    get new_entrega_personal_url

    assert_response :success
    assert_match "Entrega Personal", response.body
  end

  test "monta la franja de contexto" do
    get new_entrega_personal_url

    assert_response :success
    assert_match "panel_contexto", response.body
    assert_match "data-entrega-personal-target=\"panel\"", response.body
  end

  # PR-10.b: Yusef pidió "copiar básicamente peso, medidas y cálculo en
  # entrega personal" más el valor a pagar.
  test "monta la calculadora volumetrica" do
    get new_entrega_personal_url

    assert_response :success
    assert_match "calc-volumetrico", response.body
    assert_match "Peso a cobrar", response.body
    assert_match "Medidas (pulgadas)", response.body
  end

  test "monta el bloque de valor a pagar apuntando al cotizador" do
    get new_entrega_personal_url

    assert_response :success
    assert_match "Valor a pagar", response.body
    assert_match "data-cotizador-url-value=\"/cotizador\"", response.body
  end

  test "crea el paquete con tracking EP generado" do
    assert_difference("Paquete.count") do
      post entrega_personal_index_url, params: { paquete: {
        cliente_id: clientes(:juan).id,
        tipo_envio_id: tipo_envios(:express).id,
        proveedor_id: proveedores(:driver_entrega).id,
        sucursal_id: sucursales(:miami).id,
        peso: 3.0,
        descripcion: "Caja traida al mostrador"
      } }
    end

    paquete = Paquete.last
    assert_match(/\AEP-/, paquete.tracking)
    assert_equal "recibido_miami", paquete.estado
    assert_equal users(:digitador), paquete.user
  end

  test "un cajero no puede entrar" do
    login_as users(:cajero)

    get new_entrega_personal_url

    assert_redirected_to root_path
  end
end
