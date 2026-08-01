require "test_helper"

# PR-9.a: este controller no tenía NINGÚN filtro de autorización. Estos tests
# fijan el contrato ahora que el checkbox de la franja de contexto expone
# `completar` a los operarios.
class TareasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cliente = clientes(:juan)
    @paquete = paquetes(:recibido)
  end

  def login_as(user)
    delete session_url
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  # --- Completar desde la franja (ruta top-level, tarea sin paquete) ---

  test "completar registra quien la hizo y cuando" do
    login_as users(:digitador)
    tarea = Tarea.create!(cliente: @cliente, titulo: "Embolsar", departamento: "miami")

    post completar_tarea_url(tarea)

    tarea.reload
    assert_predicate tarea, :realizada?
    assert_equal users(:digitador), tarea.completado_por
    assert_not_nil tarea.completada_en
  end

  test "completar via turbo_stream saca la fila y actualiza el contador" do
    login_as users(:digitador)
    tarea = Tarea.create!(cliente: @cliente, titulo: "Embolsar", departamento: "miami")

    post completar_tarea_url(tarea), as: :turbo_stream

    assert_response :success
    assert_match %r{<turbo-stream action="remove" target="tarea_#{tarea.id}">}, response.body
    assert_match %r{target="tareas-pendientes-count"}, response.body
    assert_match users(:digitador).iniciales_display, response.body
  end

  test "el contador refleja las tareas que quedan abiertas del cliente" do
    login_as users(:digitador)
    completada = Tarea.create!(cliente: @cliente, titulo: "Una", departamento: "miami")
    Tarea.create!(cliente: @cliente, titulo: "Otra", departamento: "miami")

    post completar_tarea_url(completada), as: :turbo_stream

    assert_match %r{target="tareas-pendientes-count"><template>1</template>}, response.body
  end

  # --- Autorización ---

  test "un digitador puede completar pero no crear tareas" do
    login_as users(:digitador)
    tarea = Tarea.create!(cliente: @cliente, titulo: "Embolsar", departamento: "miami")

    post completar_tarea_url(tarea)
    assert_predicate tarea.reload, :realizada?

    get new_tarea_url(cliente_id: @cliente.id)
    assert_redirected_to root_path, "crear tareas es de supervisores/SAC, no del digitador"
  end

  test "un supervisor de Miami puede crear una tarea de cliente" do
    supervisor = User.create!(nombre: "Super Miami", email_address: "supermiami@test.com",
                              password: "password123", rol: "supervisor_miami", ubicacion: "miami")
    login_as supervisor

    assert_difference("Tarea.count") do
      post tareas_url, params: { tarea: { cliente_id: @cliente.id, titulo: "Llamar antes de entregar",
                                          departamento: "miami" } }
    end

    assert_redirected_to cliente_path(@cliente)
    assert_equal @cliente.id, Tarea.last.cliente_id
    assert_nil Tarea.last.paquete_id
  end

  test "un repartidor no puede borrar tareas" do
    login_as users(:repartidor)
    tarea = @paquete.tareas.create!(titulo: "Revisar")

    assert_no_difference("Tarea.count") do
      delete paquete_tarea_url(@paquete, tarea)
    end
    assert_redirected_to root_path
  end

  test "admin puede todo" do
    login_as users(:admin)

    assert_difference("Tarea.count") do
      post tareas_url, params: { tarea: { cliente_id: @cliente.id, titulo: "Desde admin" } }
    end
  end

  # --- Sigue funcionando el flujo anidado bajo paquete ---

  test "index anidado bajo paquete sigue respondiendo" do
    login_as users(:digitador)

    get paquete_tareas_url(@paquete)

    assert_response :success
  end
end
