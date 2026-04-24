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

  # Protege contra regresiones de N+1: el dashboard tiene un set fijo de
  # queries agregadas (COUNT/SUM + GROUP BY para la serie de 7 dias + 2
  # includes). Si se agregan colecciones nuevas sin eager loading, este
  # test va a fallar.
  test "dashboard ejecuta un numero acotado de queries (sin N+1)" do
    login_as users(:admin)
    # Warm caches (schema introspection, etc.)
    get root_url

    query_count = 0
    callback = ->(_name, _start, _finish, _id, payload) {
      query_count += 1 unless payload[:name].to_s.match?(/SCHEMA|CACHE|TRANSACTION/i) || payload[:cached]
    }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get root_url
    end

    # 11 KPIs individuales + 1 GROUP BY + 2 queries para paquetes_recientes
    # (paquetes + clientes) + 2 para ventas_recientes + ~5 de auth/cookie.
    # Cota holgada para acomodar overhead de Current/session.
    assert_operator query_count, :<=, 35,
      "Se ejecutaron #{query_count} queries en el dashboard (esperado ≤ 35). Posible N+1."
  end
end
