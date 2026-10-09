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

  test "la sucursal del select es la que recibe carga, no «la de Miami» a mano" do
    # C18-02: acá decía `where(ubicacion: "miami")` escrito a mano — la gemela
    # separada de /etiquetar. Una sucursal que reciba carga en otro país tiene
    # que salir, y San Pedro (que entrega, y tiene código EP) no.
    mexico = Sucursal.create!(codigo: "MEX", codigo_ep: "SMX", nombre: "México", pais: "México",
                              ubicacion: "otros", codigo_recepcion_prefix: "RMX", activo: true, recibe_carga: true)

    get new_entrega_personal_url

    assert_select "select[name='paquete[sucursal_recepcion_id]'] option[value=?]", mexico.id.to_s
    assert_select "select[name='paquete[sucursal_recepcion_id]'] option[value=?]", sucursales(:miami).id.to_s
    assert_select "select[name='paquete[sucursal_recepcion_id]'] option[value=?]", sucursales(:zeron_sps).id.to_s, count: 0
  end

  test "preselecciona la misma sucursal que /etiquetar: la del usuario, si no la de por defecto" do
    # Seguimiento de C18-02: el select nacía en blanco. Gemela de /etiquetar.
    mexico = Sucursal.create!(codigo: "DFM", codigo_ep: "SDF", nombre: "DF México", pais: "México",
                              ubicacion: "otros", activo: true, recibe_carga: true)

    get new_entrega_personal_url
    assert_select "select[name='paquete[sucursal_recepcion_id]'] option[selected][value=?]", sucursales(:miami).id.to_s

    users(:digitador).update!(sucursal: mexico)
    get new_entrega_personal_url
    assert_select "select[name='paquete[sucursal_recepcion_id]'] option[selected][value=?]", mexico.id.to_s
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
