require "test_helper"

# C17-02: dejar una tarea desde la franja de /etiquetar sin salir de la
# pantalla. Jorge, 2026-08-26: *"nos falta formas de agregar tareas"* — y la
# franja, donde #324 dice que «nacen» las tareas de Miami, era solo lectura.
class TareasDesdeLaFranjaTest < ActionDispatch::IntegrationTest
  setup do
    @cliente = clientes(:juan)
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }
  end

  test "la franja ofrece el mini-form y apunta al cliente cuando el paquete no existe" do
    get panel_contexto_url, params: { cliente_id: @cliente.id, tracking: "1ZTODAVIANOEXISTE" }

    assert_response :success
    assert_match(/Dejar una tarea/, response.body)
    assert_select "form#tarea-desde-franja-form[action=?]", tareas_path
    assert_select "input[name='tarea[tracking]'][value=?]", "1ZTODAVIANOEXISTE"
    assert_select "input[name='desde_franja'][value='1']"
    # El área por defecto es la del digitador.
    assert_select "select#tarea_departamento option[selected][value=?]", "miami"
  end

  test "si el paquete ya existe, el mini-form postea al paquete" do
    paquete = paquetes(:recibido)

    get panel_contexto_url, params: { cliente_id: paquete.cliente_id, tracking: paquete.tracking }

    assert_select "form#tarea-desde-franja-form[action=?]", paquete_tareas_path(paquete)
    assert_select "input[name='tarea[tracking]']", count: 0
  end

  test "crear desde la franja reemplaza el bloque de tareas y avisa" do
    post tareas_url, params: { desde_franja: "1", tarea: { cliente_id: @cliente.id, titulo: "Revisar la caja",
                                                           departamento: "miami", tracking: "1zfranja00000001" } },
                     as: :turbo_stream

    assert_response :success
    assert_match %r{<turbo-stream action="replace" target="tareas-de-la-franja">}, response.body
    assert_match(/Revisar la caja/, response.body)
    assert_match(/Tarea dejada para Miami/, response.body)

    tarea = Tarea.last
    assert_equal "1ZFRANJA00000001", tarea.tracking, "el tracking se guarda normalizado"
    assert_nil tarea.paquete_id
    assert_equal @cliente.id, tarea.cliente_id
  end

  test "el bloque re-pintado lleva el tracking fresco, no el de cuando cargo la franja" do
    post tareas_url, params: { desde_franja: "1", tarea: { cliente_id: @cliente.id, titulo: "x",
                                                           tracking: "1ZFRESCO00000001" } },
                     as: :turbo_stream

    assert_match(/1ZFRESCO00000001/, response.body, "el mini-form re-pintado tiene que conservar el tracking que se mandó")
  end

  test "sin titulo, solo se re-pinta el form con el error y el dialogo sigue abierto" do
    assert_no_difference("Tarea.count") do
      post tareas_url, params: { desde_franja: "1", tarea: { cliente_id: @cliente.id, titulo: "" } },
                       as: :turbo_stream
    end

    assert_response :unprocessable_entity
    assert_match %r{<turbo-stream action="replace" target="tarea-desde-franja-form">}, response.body
    assert_no_match %r{target="tareas-de-la-franja"}, response.body
    assert_match(/no puede estar en blanco|can't be blank/i, response.body)
  end

  test "desde la franja anidada al paquete, la tarea cuelga del paquete" do
    paquete = paquetes(:recibido)

    post paquete_tareas_url(paquete), params: { desde_franja: "1", tarea: { titulo: "Pesar de nuevo" } },
                                     as: :turbo_stream

    assert_response :success
    assert_equal paquete.id, Tarea.last.paquete_id
    assert_match %r{target="tareas-de-la-franja"}, response.body
  end

  test "el flujo de pagina completa no cambia: sin desde_franja redirige" do
    post tareas_url, params: { tarea: { cliente_id: @cliente.id, titulo: "Normal" } }

    assert_redirected_to cliente_path(@cliente)
  end
end
