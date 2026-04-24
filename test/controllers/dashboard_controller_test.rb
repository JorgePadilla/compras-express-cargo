require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  def login_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  test "admin autenticado ve el dashboard" do
    login_as users(:admin)
    get root_url
    assert_response :success
    assert_match "Dashboard", response.body
  end

  test "supervisor_miami ve el dashboard" do
    supervisor = User.create!(
      nombre: "Supervisor", email_address: "sup_miami@test.com", password: "password123",
      rol: "supervisor_miami", ubicacion: "miami", activo: true
    )
    login_as supervisor
    get root_url
    assert_response :success
  end

  test "digitador_miami es redirigido a etiquetar" do
    login_as users(:digitador)
    get root_url
    assert_redirected_to etiquetar_path
    assert_match(/permiso/i, flash[:alert])
  end

  test "cajero es redirigido a caja" do
    login_as users(:cajero)
    get root_url
    assert_redirected_to caja_path
  end

  test "entrega_despacho es redirigido a entregas" do
    login_as users(:repartidor)
    get root_url
    assert_redirected_to entregas_path
  end

  test "usuario no autenticado es redirigido al login" do
    get root_url
    assert_redirected_to new_session_path
  end
end
