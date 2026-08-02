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
        ubicacion: "miami", codigo_recepcion_prefix: "RLA", activo: true
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
        codigo: "ZZZ", nombre: "Hack", codigo_recepcion_prefix: "RZ"
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
end
