require "test_helper"

# `RP-45` · El jefe de SAC no veía la cola de SAC.
#
# El síntoma quedó anotado en esa fila hace meses: *"el jefe de SAC
# (`supervisor_sac`) hoy no ve la cola de SAC — no está en ninguna lista de
# tareas ni en la segmentación por área"*. Era literal y era en **tres** lugares:
#
#   · `Tarea::DEPARTAMENTOS_POR_ROL` — `fetch(rol, [])` le devolvía nada, así que
#     solo veía las tareas sin área;
#   · `TareasController::GESTION_ROLES` — no podía editar ni cerrar;
#   · `EJECUCION_ROLES`, que sale de la anterior — **ni siquiera podía abrir
#     `/tareas`**, porque traba el `index`.
#
# No hacía falta contestar `RP-45` para arreglarlo: la pregunta abierta es
# **quién puede crear** una tarea. Que el jefe de un área vea la cola de su área
# no es una pregunta — y `User::NOTAS_POR_ROL` ya lo trataba así, que es la tabla
# que ésta espeja a propósito.
class JefeDeSacVeSuColaTest < ActionDispatch::IntegrationTest
  setup do
    @jefe = users(:admin).dup
    @jefe.assign_attributes(email_address: "jefa.sac@cec.test", rol: "supervisor_sac",
                            nombre: "Michelle", password: "password123",
                            password_confirmation: "password123")
    @jefe.save!
  end

  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def tarea_de(departamento)
    Tarea.create!(titulo: "Llamar al cliente", cliente: clientes(:juan),
                  departamento: departamento, estado: "pendiente", origen: "manual")
  end

  # ── Lo que no podía hacer ───────────────────────────────────────────────

  test "puede abrir la bandeja de tareas" do
    ingresar(@jefe)
    get tareas_url

    assert_response :success, "ni siquiera entraba: EJECUCION_ROLES traba el index"
  end

  test "ve la cola de su área" do
    suya = tarea_de("sac")

    assert_includes Tarea.visibles_para(@jefe), suya,
                    "el jefe de SAC no veía las tareas de SAC"
  end

  test "ve lo mismo que su equipo, ni más ni menos" do
    assert_equal Tarea::DEPARTAMENTOS_POR_ROL["sac"],
                 Tarea::DEPARTAMENTOS_POR_ROL["supervisor_sac"],
                 "el jefe y su agente tienen que ver la misma cola"
  end

  test "puede gestionar tareas, como el resto de los supervisores" do
    assert_includes TareasController::GESTION_ROLES, "supervisor_sac"
  end

  # ── Y lo que no se le abrió de más ──────────────────────────────────────

  test "no ve la cola de Miami" do
    de_miami = tarea_de("miami")

    assert_not_includes Tarea.visibles_para(@jefe), de_miami
  end

  # ── La lista, en un solo lugar ──────────────────────────────────────────
  #
  # El par estaba escrito a mano en `PermisosDelSistema` y faltaba en las de
  # tareas. Es cómo se desincronizó.

  test "notas y tareas segmentan igual para SAC" do
    User::ROLES_DE_SAC.each do |rol|
      notas = User::NOTAS_POR_ROL.fetch(rol).map(&:first)
      deptos = Tarea::DEPARTAMENTOS_POR_ROL.fetch(rol)

      assert_includes notas, :notas_sac
      assert_includes deptos, "sac",
                      "#{rol} ve las notas de SAC pero no sus tareas: se contradicen"
    end
  end

  test "la política de marketing usa la misma lista, no una copia" do
    User::ROLES_DE_SAC.each do |rol|
      assert PermisosDelSistema.politica(rol, :marketing),
             "#{rol} perdió marketing al derivar la lista"
    end
  end
end
