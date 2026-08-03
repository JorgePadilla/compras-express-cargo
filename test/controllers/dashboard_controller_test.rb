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

    # KPIs hoy (4) + KPIs ayer (4) + semana/mes (4) + pipeline (6) +
    # series 7d ×4 (paquetes/ingresos/entregas/pre_alertas) + activity recientes (4) +
    # auth/session (~5). Cota holgada para overhead.
    assert_operator query_count, :<=, 50,
      "Se ejecutaron #{query_count} queries en el dashboard (esperado ≤ 50). Posible N+1."
  end

  # ── Mission Control: nuevas instance vars ──

  test "expone deltas, sparklines y health_status" do
    login_as users(:admin)
    get root_url
    assert_response :success
    %i[ingresos_ayer entregas_ayer paquetes_recibidos_ayer pre_alertas_ayer
       ingresos_7_dias entregas_7_dias pre_alertas_7_dias paquetes_7_dias
       health_status].each do |ivar|
      assert_not_nil @controller.instance_variable_get("@#{ivar}"),
        "Esperaba que @#{ivar} estuviera seteado"
    end
    health = @controller.instance_variable_get(:@health_status)
    assert_includes %i[ok warn alert], health[:level]
    assert health[:message].is_a?(String)
  end

  # ── Shortcuts agrupados (role-based visibility) ──

  test "admin ve todas las áreas de shortcuts" do
    login_as users(:admin)
    get root_url
    assert_response :success
    groups = @controller.instance_variable_get(:@shortcut_groups)
    areas = groups.map { |g| g[:area] }
    assert_includes areas, "Logística"
    assert_includes areas, "Facturación y Cobro"
    assert_includes areas, "Entregas"
    assert_includes areas, "Caja Diaria"
    assert_includes areas, "Clientes"
    assert_includes areas, "Configuración"
    # PR-10.c: "Marketing" se oculta hasta que exista el módulo — sus 3 cards
    # apuntaban a "#" y no hacían nada.
    assert_not_includes areas, "Marketing"
  end

  test "no quedan cards muertas apuntando a #" do
    login_as users(:admin)
    get root_url

    hrefs = @controller.instance_variable_get(:@shortcut_groups).flat_map { |g| g[:cards] }.map { |c| c[:href] }

    assert_not_includes hrefs, "#", "una card que no lleva a ningún lado es ruido para el operario"
  end

  test "el dashboard incluye Entrega Personal" do
    login_as users(:admin)
    get root_url

    titulos = @controller.instance_variable_get(:@shortcut_groups).flat_map { |g| g[:cards] }.map { |c| c[:title] }

    assert_includes titulos, "Entrega Personal"
    assert_includes titulos, "Tabla de Servicios"
  end

  test "supervisor_miami ve Logística + Clientes pero no Facturación/Caja Diaria/Configuración" do
    sup = User.create!(nombre: "Sup M", email_address: "sup_m_dash@test.com", password: "password123",
                       rol: "supervisor_miami", ubicacion: "miami", activo: true)
    login_as sup
    get root_url
    assert_response :success
    groups = @controller.instance_variable_get(:@shortcut_groups)
    areas = groups.map { |g| g[:area] }
    assert_includes areas, "Logística"
    assert_includes areas, "Clientes"
    assert_not_includes areas, "Facturación y Cobro"
    assert_not_includes areas, "Caja Diaria"
    assert_not_includes areas, "Entregas"
    assert_not_includes areas, "Configuración"
  end

  test "supervisor_caja ve Facturación + Caja Diaria + Entregas pero no Configuración" do
    sup = User.create!(nombre: "Sup C", email_address: "sup_c_dash@test.com", password: "password123",
                       rol: "supervisor_caja", ubicacion: "honduras", activo: true)
    login_as sup
    get root_url
    assert_response :success
    groups = @controller.instance_variable_get(:@shortcut_groups)
    areas = groups.map { |g| g[:area] }
    assert_includes areas, "Facturación y Cobro"
    assert_includes areas, "Caja Diaria"
    assert_includes areas, "Entregas"
    assert_includes areas, "Clientes"
    assert_not_includes areas, "Configuración"
  end

  test "supervisor_prefactura ve Facturación pero no Caja Diaria ni Configuración" do
    sup = User.create!(nombre: "Sup P", email_address: "sup_p_dash@test.com", password: "password123",
                       rol: "supervisor_prefactura", ubicacion: "honduras", activo: true)
    login_as sup
    get root_url
    assert_response :success
    groups = @controller.instance_variable_get(:@shortcut_groups)
    areas = groups.map { |g| g[:area] }
    assert_includes areas, "Facturación y Cobro"
    assert_includes areas, "Clientes"
    assert_not_includes areas, "Caja Diaria"
    assert_not_includes areas, "Entregas"
    assert_not_includes areas, "Configuración"
  end

  test "shortcut_groups omite áreas vacías" do
    login_as users(:admin)
    get root_url
    groups = @controller.instance_variable_get(:@shortcut_groups)
    groups.each do |g|
      assert g[:cards].any?, "El área #{g[:area]} está vacía y no debería renderizarse"
    end
  end
end
