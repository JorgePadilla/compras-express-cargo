require "test_helper"

class SucursalesControllerTest < ActionDispatch::IntegrationTest
  def login_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  test "admin ve el index" do
    login_as users(:admin)
    get sucursales_url
    assert_response :success
  end

  test "admin puede crear sucursal" do
    login_as users(:admin)
    assert_difference("Sucursal.count", 1) do
      post sucursales_url, params: { sucursal: {
        codigo: "LAX", nombre: "Los Angeles", pais: "USA",
        ubicacion: "miami", activo: true
      } }
    end
    assert_redirected_to sucursales_url
  end

  test "admin no puede borrar sucursal con paquetes" do
    login_as users(:admin)
    suc = sucursales(:miami)
    paquete = paquetes(:recibido)
    paquete.update_column(:sucursal_id, suc.id)

    assert_no_difference("Sucursal.count") do
      delete sucursal_url(suc)
    end
    assert_redirected_to sucursales_url
    assert_match(/paquetes vinculados/i, flash[:alert])
  end

  test "digitador no puede acceder al index" do
    login_as users(:digitador)
    get sucursales_url
    assert_redirected_to root_path
    assert_match(/administradores/i, flash[:alert])
  end

  test "cajero no puede crear sucursales" do
    login_as users(:cajero)
    assert_no_difference("Sucursal.count") do
      post sucursales_url, params: { sucursal: {
        codigo: "ZZZ", nombre: "Hack"
      } }
    end
    assert_redirected_to root_path
  end

  test "no autenticado es redirigido al login" do
    get sucursales_url
    assert_redirected_to new_session_path
  end

  test "digitador no puede editar sucursal" do
    login_as users(:digitador)
    suc = sucursales(:miami)
    patch sucursal_url(suc), params: { sucursal: { nombre: "Hacked" } }
    assert_redirected_to root_path
    assert_not_equal "Hacked", suc.reload.nombre
  end

  test "digitador no puede borrar sucursal" do
    login_as users(:digitador)
    suc = sucursales(:humuya_tgu)
    assert_no_difference("Sucursal.count") do
      delete sucursal_url(suc)
    end
    assert_redirected_to root_path
  end

  test "se crea sin prefijo de recepcion, y marcar recepcion por defecto desmarca la otra" do
    # Seguimiento de C18-02: crear DF México no puede exigir inventar un prefijo
    # que nadie lee desde RP-17; y solo una es la de por defecto.
    login_as users(:admin)
    assert_difference("Sucursal.count") do
      post sucursales_url, params: { sucursal: { codigo: "DFM", nombre: "DF México", pais: "México", ubicacion: "otros",
                                                 activo: "1", recibe_carga: "1", recepcion_por_defecto: "1" } }
    end
    mexico = Sucursal.find_by!(codigo: "DFM")
    assert_nil mexico.codigo_recepcion_prefix
    assert_predicate mexico, :recepcion_por_defecto?
    assert_not sucursales(:miami).reload.recepcion_por_defecto?

    get sucursales_url
    assert_match "Recepción por defecto", response.body
    assert_match "Recibe carga", response.body
    assert_match "RDFM#{Date.current.strftime('%y%m')}000001", response.body
    assert_no_match(/RMI-XXXXXX/, response.body)
  end

  test "el checkbox de recibe carga se guarda" do
    # C18-02: es dato, no regla escondida. Yusef crea México y la marca.
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }

    post sucursales_url, params: { sucursal: { codigo: "MEX", nombre: "México", pais: "México", ubicacion: "otros", activo: "1", recibe_carga: "1" } }

    assert_predicate Sucursal.find_by!(codigo: "MEX"), :recibe_carga?
  end
end
