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
    assert_includes areas, "Miami"
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

  # El home es el punto de entrada del admin. Si una pantalla solo se llega
  # desde el sidebar, en la práctica no existe para quien no lo explora.
  test "el dashboard llega a todos los catalogos que el negocio mantiene" do
    login_as users(:admin)
    get root_url

    hrefs = @controller.instance_variable_get(:@shortcut_groups).flat_map { |g| g[:cards] }.map { |c| c[:href] }

    # `categoria_precios_path` salió de la lista en PR-C7.12: los grupos de
    # clientes dejaron de ser una pantalla y se administran dentro de la Tabla de
    # Servicios, así que la tarjeta que llega a ellos es la de servicios.
    [
      servicios_path, tarifas_recolecta_path,
      servicios_extra_path, proveedores_path, motivos_retencion_path,
      plantillas_notas_cliente_path, motivos_envio_politica_path
    ].each do |ruta|
      assert_includes hrefs, ruta, "#{ruta} solo se alcanzaba desde el sidebar"
    end

    assert_not_includes hrefs, categoria_precios_path,
                        "los grupos de clientes no son una pantalla aparte; se administran en /servicios"
  end

  # Guard contra la desincronización que ya pasó una vez: se quitaron las
  # cards muertas del dashboard y quedaron vivas en el sidebar.
  test "el sidebar tampoco tiene links muertos" do
    login_as users(:admin)
    get root_url

    sidebar = response.body[/<aside[^>]*id="sidebar".*?<\/aside>/m]
    assert sidebar, "no se encontro el sidebar"

    muertos = sidebar.scan(/<a[^>]+href="#"/)
    assert_empty muertos, "el sidebar tiene #{muertos.size} link(s) que no llevan a ningun lado"
  end

  test "cada card del dashboard apunta a una ruta que existe" do
    login_as users(:admin)
    get root_url

    hrefs = @controller.instance_variable_get(:@shortcut_groups).flat_map { |g| g[:cards] }.map { |c| c[:href] }

    hrefs.each do |href|
      assert Rails.application.routes.recognize_path(href),
             "#{href} no corresponde a ninguna ruta"
    rescue ActionController::RoutingError
      flunk "#{href} no corresponde a ninguna ruta"
    end
  end

  test "supervisor_miami ve Miami + Logística + Clientes pero no Facturación/Caja Diaria/Configuración" do
    sup = User.create!(nombre: "Sup M", email_address: "sup_m_dash@test.com", password: "password123",
                       rol: "supervisor_miami", ubicacion: "miami", activo: true)
    login_as sup
    get root_url
    assert_response :success
    groups = @controller.instance_variable_get(:@shortcut_groups)
    areas = groups.map { |g| g[:area] }
    assert_includes areas, "Miami"
    # Logística le sigue apareciendo, pero ya no por Etiquetar: le quedan
    # Pre-Alertas y Todos los Paquetes, que `can_access?` deja ver a cualquiera.
    assert_includes areas, "Logística"
    assert_includes areas, "Clientes"
    assert_not_includes areas, "Facturación y Cobro"
    assert_not_includes areas, "Caja Diaria"
    assert_not_includes areas, "Entregas"
    assert_not_includes areas, "Configuración"
  end

  # PR-C7.36. Los tests de arriba solo miran los nombres de las áreas, y con
  # `assert_includes` "Logística" seguía pasando tuviera adentro lo que tuviera.
  # Este fija la intención: qué card cae en qué bloque. Sin él, alguien devuelve
  # Etiquetar a Logística y la suite no se entera.
  test "el mostrador de Miami vive en su propio bloque, no adentro de Logística" do
    login_as users(:admin)
    get root_url

    grupos = @controller.instance_variable_get(:@shortcut_groups).index_by { |g| g[:area] }
    titulos = ->(area) { grupos.fetch(area)[:cards].map { |c| c[:title] } }

    # PR-M10 · Miami es **el mostrador** —recibir el paquete y entregarlo en
    # mano—; **mover la carga es Logística**. El manifiesto se fue de acá
    # (Jorge: *"hay que mover los links de mover carga al grupo de logística"*)
    # y «Recibir Carga», que nunca había tenido card, entró con él.
    assert_equal [ "Etiquetar", "Entrega Personal" ], titulos.call("Miami")
    assert_equal [ "Pre-Alertas", "Manifiestos", "Recibir Carga", "Todos los Paquetes" ],
                 titulos.call("Logística")

    areas = grupos.keys
    assert_operator areas.index("Miami"), :<, areas.index("Logística"),
                    "Miami es la operación diaria: va primero en el home"
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
    assert_not_includes areas, "Miami", "el mostrador de Miami no es de este rol"
  end

  # C21-02 · San Pedro le pone al manifiesto la guía del proveedor y la fecha de
  # recibido en Honduras, así que llega a la pantalla — pero por Logística, no
  # por el mostrador de Miami.
  test "el jefe de Honduras ve el manifiesto en Logística y no ve Miami" do
    login_as users(:supervisor_prefactura)
    get root_url

    grupos = @controller.instance_variable_get(:@shortcut_groups).index_by { |g| g[:area] }
    assert_includes grupos.fetch("Logística")[:cards].map { |c| c[:title] }, "Manifiestos"
    assert_not_includes grupos.keys, "Miami"
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
    assert_not_includes areas, "Miami", "el mostrador de Miami no es de este rol"
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
