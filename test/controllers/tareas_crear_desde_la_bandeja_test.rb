require "test_helper"

# C17-01 · Jorge, 2026-08-26: *"creo que nos falta formas de agregar tareas"*.
#
# Había tres entradas, todas a página completa y todas exigían estar parado en
# un paquete o en un cliente. `/tareas/new` a secas era un callejón sin salida:
# el cliente solo llegaba por `?cliente_id=` y sin él la tarea no se guardaba —
# por eso la bandeja (PR-C7.40) no tenía «Nueva tarea». Las tareas de cliente no
# se podían editar ni borrar. Y dos botones tenían el gate equivocado.
class TareasCrearDesdeLaBandejaTest < ActionDispatch::IntegrationTest
  setup do
    @cliente = clientes(:juan)
    @paquete = paquetes(:recibido)
  end

  def entrar(user)
    delete session_url
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def crear_usuario(rol)
    User.create!(nombre: "Tester #{rol}", email_address: "#{rol}_crear@test.com",
                 password: "password123", rol: rol, ubicacion: "miami", activo: true)
  end

  # ── La bandeja crea ─────────────────────────────────────────────────────

  test "la bandeja ofrece «Nueva tarea» y el form pide el cliente" do
    entrar users(:digitador)

    get tareas_url
    assert_match(/Nueva tarea/, response.body)
    assert_match %r{href="#{new_tarea_path}"}, response.body

    get new_tarea_url
    assert_response :success
    assert_match(/data-controller="client-autocomplete"/, response.body, "sin cliente elegible el form es un callejón")
    assert_match(/tarea\[tracking\]/, response.body)
  end

  test "desde la ficha el cliente viene fijo y no sale el autocomplete" do
    entrar users(:digitador)

    get new_tarea_url(cliente_id: @cliente.id)
    assert_no_match(/data-controller="client-autocomplete"/, response.body)
    assert_match(/#{@cliente.codigo}/, response.body)
  end

  test "crear con cliente elegido la deja en el cliente" do
    entrar users(:digitador)

    assert_difference("Tarea.count") do
      post tareas_url, params: { tarea: { cliente_id: @cliente.id, titulo: "Llamar antes de despachar" } }
    end
    assert_redirected_to cliente_path(@cliente)
    assert_nil Tarea.last.paquete_id
  end

  test "el area por defecto es la del que crea" do
    entrar users(:cajero)

    get new_tarea_url
    assert_select "select#tarea_departamento option[selected][value=?]", "caja"
  end

  # ── Con tracking, cuelga del paquete ────────────────────────────────────

  test "con tracking cuelga del paquete, y en un split de la Caja 1" do
    cajas = Paquete.crear_split!(
      attrs: { tracking: "1ZSPLITTAREA0001", cliente: @cliente, tipo_envio: tipo_envios(:cer),
               descripcion: "Dos cajas", estado: "recibido_miami", user: users(:digitador),
               sucursal_recepcion: sucursales(:miami) },
      total_cajas: 2
    )
    entrar users(:digitador)

    post tareas_url, params: { tarea: { cliente_id: @cliente.id, titulo: "Revisar la caja",
                                        tracking: "1zsplittarea0001" } }

    tarea = Tarea.last
    caja1 = cajas.min_by(&:numero_caja)
    assert_equal caja1.id, tarea.paquete_id, "tiene que ir a la Caja 1"
    assert_redirected_to paquete_tareas_path(caja1)
  end

  test "un tracking que no existe no guarda nada y lo dice" do
    entrar users(:digitador)

    assert_no_difference("Tarea.count") do
      post tareas_url, params: { tarea: { cliente_id: @cliente.id, titulo: "x", tracking: "1ZNOEXISTE000001" } }
    end
    assert_response :unprocessable_entity
    assert_match(/No hay ningún paquete con el tracking 1ZNOEXISTE000001/, response.body)
    assert_match(/#{@cliente.codigo}/, response.body, "el form vuelve mostrando a quién apunta el cliente elegido")
  end

  test "el tracking se busca dentro del cliente elegido: el mismo codigo en otro cliente no cuenta" do
    otro = clientes(:maria)
    Paquete.create!(cliente: otro, tipo_envio: tipo_envios(:cer), tracking: "1ZDEMARIA0000009",
                    descripcion: "y", estado: "recibido_miami", user: users(:digitador),
                    sucursal_recepcion: sucursales(:miami))
    entrar users(:digitador)

    assert_no_difference("Tarea.count") do
      post tareas_url, params: { tarea: { cliente_id: @cliente.id, titulo: "x", tracking: "1ZDEMARIA0000009" } }
    end
    assert_response :unprocessable_entity
  end

  test "sin cliente pero con tracking, el cliente sale del paquete" do
    entrar users(:digitador)

    post tareas_url, params: { tarea: { titulo: "Revisar", tracking: @paquete.tracking } }

    tarea = Tarea.last
    assert_equal @paquete.id, tarea.paquete_id
    assert_equal @paquete.cliente_id, tarea.cliente_id
  end

  # ── Las tareas de cliente se editan y se borran ─────────────────────────

  test "una tarea de cliente se puede editar y borrar por la ruta top-level" do
    entrar crear_usuario("supervisor_miami")
    tarea = Tarea.create!(cliente: @cliente, titulo: "Vieja", departamento: "miami")

    get edit_tarea_url(tarea)
    assert_response :success

    patch tarea_url(tarea), params: { tarea: { titulo: "Nueva" } }
    assert_redirected_to cliente_path(@cliente)
    assert_equal "Nueva", tarea.reload.titulo

    assert_difference("Tarea.count", -1) { delete tarea_url(tarea) }
  end

  test "la bandeja lleva el lapiz a donde la tarea esta pegada" do
    entrar crear_usuario("supervisor_miami")
    de_cliente = Tarea.create!(cliente: @cliente, titulo: "De cliente", departamento: "miami")
    de_paquete = @paquete.tareas.create!(titulo: "De paquete", departamento: "miami")

    get tareas_url
    assert_match %r{href="#{edit_tarea_path(de_cliente)}"}, response.body
    assert_match %r{href="#{edit_paquete_tarea_path(@paquete, de_paquete)}"}, response.body
  end

  test "el digitador no ve el lapiz en la bandeja" do
    entrar users(:digitador)
    tarea = Tarea.create!(cliente: @cliente, titulo: "x", departamento: "miami")

    get tareas_url
    assert_no_match %r{href="#{edit_tarea_path(tarea)}"}, response.body
  end

  # ── Los gates que estaban mal ───────────────────────────────────────────

  test "el digitador ve «Nueva tarea» en las tareas del paquete pero no «Editar» ni «Borrar»" do
    entrar users(:digitador)
    @paquete.tareas.create!(titulo: "x")

    get paquete_tareas_url(@paquete)
    assert_match(/Nueva tarea/, response.body)
    assert_no_match(/>Editar</, response.body)
    assert_no_match(/>Borrar</, response.body)
  end

  test "supervisor de caja y SAC ven «Nueva tarea» en la ficha del paquete" do
    %w[supervisor_caja sac].each do |rol|
      entrar crear_usuario(rol)
      get paquete_url(@paquete)
      assert_match %r{href="#{new_paquete_tarea_path(@paquete)}"}, response.body, "#{rol} no ve el botón"
    end
  end

  test "cajero y repartidor tambien crean" do
    [ users(:cajero), users(:repartidor) ].each do |user|
      entrar user
      assert_difference("Tarea.count") do
        post tareas_url, params: { tarea: { cliente_id: @cliente.id, titulo: "Desde #{user.rol}" } }
      end
    end
  end

  # ── El límite que sobrevive a cualquier respuesta de Yusef ──────────────

  test "el cliente del portal nunca llega a crear una tarea" do
    # C16-01: *"el cliente no puede poner una tarea, solo nosotros"*. Se está
    # ensanchando la creación la misma semana en que él la achicó: personal
    # sí, cliente nunca.
    delete session_url
    post session_url, params: { email_address: @cliente.email, password: "Cliente123!" }
    get cuenta_root_url
    assert_response :success, "el cliente tiene que haber entrado al portal para que el test pruebe algo"

    get new_tarea_url
    assert_response :redirect
    assert_no_difference("Tarea.count") do
      post tareas_url, params: { tarea: { cliente_id: @cliente.id, titulo: "Desde el portal" } }
    end
  end
end
