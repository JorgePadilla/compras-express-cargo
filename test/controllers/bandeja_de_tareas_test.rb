require "test_helper"

# La bandeja de tareas: lo que mi área tiene abierto, sin tener que saber de
# antemano en qué paquete está.
#
# Jorge, mirando el menú: *"veo que falta la parte de tareas"*, *"faltan los
# links del menú"*. Faltaba el link porque faltaba la pantalla: `TareasController#index`
# exigía un paquete (`@paquete.tareas`), así que las tareas solo se veían
# entrando a UN paquete o a UN cliente.
#
# Y el caso que lo vuelve necesario, que Jorge señaló enseguida: *"tenemos tareas
# en etiquetar, que tiene que ir conectada a algo"*. Las tareas que nacen en
# `/etiquetar` **cuelgan del cliente y no del paquete** —cuando el operario
# escanea, el paquete todavía no existe— así que no aparecían en la lista de
# ningún paquete. Se veían solo si alguien volvía a escanear a ese cliente.
class BandejaDeTareasTest < ActionDispatch::IntegrationTest
  setup do
    @paquete = paquetes(:recibido)
    @cliente = clientes(:juan)
  end

  def entrar_como(rol)
    user = User.create!(nombre: "Tester #{rol}", email_address: "#{rol}_bandeja@test.com",
                        password: "password123", rol: rol, ubicacion: "miami", activo: true)
    post session_url, params: { email_address: user.email_address, password: "password123" }
    user
  end

  # ── La tarea de /etiquetar, que no cuelga de ningún paquete ─────────────

  test "una tarea de cliente sin paquete aparece en la bandeja" do
    entrar_como("supervisor_miami")
    Tarea.create!(titulo: "Sacarle foto a la caja", cliente: @cliente,
                  departamento: "miami", origen: "manual")

    get tareas_url

    assert_response :success
    assert_match "Sacarle foto a la caja", response.body
  end

  test "y lleva a la ficha del cliente, que es lo unico a lo que esta pegada" do
    entrar_como("supervisor_miami")
    Tarea.create!(titulo: "Sin paquete todavia", cliente: @cliente,
                  departamento: "miami", origen: "manual")

    get tareas_url

    assert_select "a[href=?]", cliente_path(@cliente)
  end

  test "la que si tiene paquete lleva al paquete" do
    entrar_como("supervisor_miami")
    Tarea.create!(titulo: "Con paquete", paquete: @paquete, cliente: @cliente,
                  departamento: "miami", origen: "manual")

    get tareas_url

    assert_select "a[href=?]", paquete_tareas_path(@paquete)
  end

  # Sin esto, una tarea sin paquete solo se podía cerrar si alguien volvía a
  # escanear a ese cliente en /etiquetar.
  test "se puede marcar hecha desde la bandeja" do
    entrar_como("supervisor_miami")
    tarea = Tarea.create!(titulo: "Cerrable", cliente: @cliente,
                          departamento: "miami", origen: "manual")

    post completar_tarea_url(tarea)

    assert tarea.reload.realizada?
  end

  # ── El filtro por área ──────────────────────────────────────────────────
  #
  # Misma segmentación que las notas permanentes: un digitador de Miami no
  # tiene por qué cargar con la cola de Caja.

  test "cada quien ve la cola de su area" do
    Tarea.create!(titulo: "Cosa de Miami", cliente: @cliente, departamento: "miami", origen: "manual")
    Tarea.create!(titulo: "Cosa de Caja",  cliente: @cliente, departamento: "caja",  origen: "manual")

    entrar_como("digitador_miami")
    get tareas_url

    assert_match "Cosa de Miami", response.body
    assert_no_match(/Cosa de Caja/, response.body)
  end

  test "la que no tiene area la ve cualquiera" do
    Tarea.create!(titulo: "Para todos", cliente: @cliente, departamento: nil, origen: "manual")

    entrar_como("digitador_miami")
    get tareas_url

    assert_match "Para todos", response.body
  end

  # ── Los filtros de la pantalla ──────────────────────────────────────────

  test "por defecto no trae las realizadas" do
    entrar_como("supervisor_miami")
    hecha = Tarea.create!(titulo: "Ya estaba hecha", cliente: @cliente,
                          departamento: "miami", origen: "manual")
    hecha.completar!(Current.user || User.first)

    get tareas_url
    assert_no_match(/Ya estaba hecha/, response.body)

    get tareas_url(realizadas: "1")
    assert_match "Ya estaba hecha", response.body
  end

  test "solo las mias filtra por asignado" do
    yo = entrar_como("supervisor_miami")
    Tarea.create!(titulo: "Mia", cliente: @cliente, departamento: "miami",
                  origen: "manual", asignado_a: yo)
    Tarea.create!(titulo: "De otro", cliente: @cliente, departamento: "miami", origen: "manual")

    get tareas_url(mias: "1")

    assert_match "Mia", response.body
    assert_no_match(/De otro/, response.body)
  end

  # Apagar un filtro no puede resetear el otro.
  test "los links conservan el otro filtro" do
    entrar_como("supervisor_miami")
    Tarea.create!(titulo: "Alguna", cliente: @cliente, departamento: "miami", origen: "manual")

    get tareas_url(realizadas: "1")

    assert_select "a[href=?]", tareas_path(mias: "1", realizadas: "1")
  end

  # ── Que siga andando lo de antes ────────────────────────────────────────

  test "la lista de un paquete sigue siendo la de ese paquete" do
    entrar_como("supervisor_miami")
    Tarea.create!(titulo: "De este paquete", paquete: @paquete, cliente: @cliente, origen: "manual")
    Tarea.create!(titulo: "De otro lado", cliente: @cliente, origen: "manual")

    get paquete_tareas_url(@paquete)

    assert_match "De este paquete", response.body
    assert_no_match(/De otro lado/, response.body)
  end

  # ── El menú ─────────────────────────────────────────────────────────────

  test "el sidebar y el dashboard llevan a la bandeja" do
    admin = users(:admin)
    post session_url, params: { email_address: admin.email_address, password: "password123" }

    get root_url

    assert_select "a[href=?]", tareas_path
    hrefs = @controller.instance_variable_get(:@shortcut_groups).flat_map { |g| g[:cards] }.map { |c| c[:href] }
    assert_includes hrefs, tareas_path
  end

  # Este test decía *"a quien no ejecuta tareas no se le ofrece"* y usaba de
  # ejemplo a `supervisor_sac`… que era el único que quedaba afuera **por un
  # olvido**, no por una decisión: faltaba en las tres listas de tareas, que es
  # el síntoma que `RP-45` traía anotado y se arregló el 2026-09-01.
  #
  # O sea que el test fijaba el bug como si fuera la regla. Arreglado el olvido
  # **ya no queda ningún rol afuera**, así que el ejemplo no existe y el test
  # tampoco puede.
  #
  # Lo que se queda en su lugar es la guarda de verdad: hoy **todo el personal
  # ejecuta tareas**, que es la respuesta provisoria de Jorge en `RP-45` (*"la
  # deja cualquiera del personal que las ejecuta"*). Escrito así, el día que
  # alguien agregue un rol nuevo este test falla hasta que decida si ejecuta o
  # no — que es justo la decisión que la primera vez nadie tomó.
  test "todo el personal ejecuta tareas, y agregar un rol obliga a decidirlo" do
    del_personal = User.rols.keys - [ "admin" ]

    assert_equal del_personal.sort, TareasController::EJECUCION_ROLES.sort,
                 "hay un rol que no está en EJECUCION_ROLES: ¿ejecuta tareas o no? " \
                 "Decidilo y actualizá la lista — no lo dejes afuera por omisión."
  end

  test "el jefe de SAC entra, que era el que faltaba" do
    entrar_como("supervisor_sac")

    get tareas_url

    assert_response :success
  end
end
