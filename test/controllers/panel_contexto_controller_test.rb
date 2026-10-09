require "test_helper"

# PR-9.b: la franja de contexto de /etiquetar y /entrega_personal.
class PanelContextoControllerTest < ActionDispatch::IntegrationTest
  setup do
    login_as users(:digitador)
    @cliente = clientes(:juan)
  end

  def login_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  test "sin cliente muestra el estado vacio" do
    get panel_contexto_url

    assert_response :success
    assert_match "Sin cliente seleccionado", response.body
  end

  test "con cliente muestra su nombre y codigo" do
    get panel_contexto_url, params: { cliente_id: @cliente.id }

    assert_response :success
    assert_match @cliente.nombre_completo, response.body
    assert_match @cliente.codigo, response.body
  end

  test "lista las tareas abiertas del cliente" do
    tarea = Tarea.create!(cliente: @cliente, titulo: "Embolsar todos los productos", departamento: "miami")

    get panel_contexto_url, params: { cliente_id: @cliente.id }

    assert_response :success
    assert_match "Embolsar todos los productos", response.body
    assert_match "tarea_#{tarea.id}", response.body
  end

  test "no muestra tareas realizadas" do
    tarea = Tarea.create!(cliente: @cliente, titulo: "Ya se hizo esto", departamento: "miami")
    tarea.completar!(users(:digitador))

    get panel_contexto_url, params: { cliente_id: @cliente.id }

    assert_response :success
    assert_no_match "Ya se hizo esto", response.body
  end

  test "un digitador de Miami no ve tareas de Caja" do
    Tarea.create!(cliente: @cliente, titulo: "Cobrar saldo vencido", departamento: "caja")

    get panel_contexto_url, params: { cliente_id: @cliente.id }

    assert_response :success
    assert_no_match "Cobrar saldo vencido", response.body
  end

  test "muestra las notas permanentes del area del usuario y oculta las demas" do
    @cliente.update!(notas_miami: "Siempre embolsarle todo",
                     notas_caja:  "Tiene saldo pendiente de marzo")

    get panel_contexto_url, params: { cliente_id: @cliente.id }

    assert_response :success
    assert_match "Siempre embolsarle todo", response.body
    assert_no_match "Tiene saldo pendiente de marzo", response.body,
                    "un digitador de Miami no debe ver las notas de Caja"
  end

  test "con tracking muestra las notas especiales de esa pre-alerta" do
    pap = PreAlertaPaquete.create!(
      pre_alerta: pre_alertas(:activa),
      tracking: "1Z999PANELNOTA1",
      descripcion: "Caja mixta",
      instrucciones: "El celular por Express, la ropa por maritimo"
    )

    get panel_contexto_url, params: { cliente_id: pap.pre_alerta.cliente_id, tracking: pap.tracking }

    assert_response :success
    assert_match "El celular por Express, la ropa por maritimo", response.body
  end

  # C30-10 · La gemela de la PESA: la franja de /etiquetar arma las notas con
  # el mismo helper, y una caja ya recibida traía la nota de grupo dos veces
  # —la de la pre-alerta y la copia que Miami le puso a la caja—.
  test "la nota de grupo copiada a la caja sale una sola vez" do
    pa = PreAlerta.create!(numero_documento: "PA-N#{SecureRandom.hex(3).upcase}", cliente: @cliente,
                           tipo_envio: tipo_envios(:aereo), consolidado: true, estado: "pre_alerta",
                           titulo: "Consolidado", creado_por_tipo: "usuario", creado_por_id: users(:admin).id,
                           notas_grupo: "Meter todo en una sola caja")
    paquete = Paquete.create!(tracking: "1Z999PANELNOTA2", cliente: @cliente, tipo_envio: tipo_envios(:cer),
                              sucursal_recepcion: sucursales(:miami), estado: "recibido_miami", descripcion: "Ropa")
    pa.pre_alerta_paquetes.create!(tracking: paquete.tracking, descripcion: "Ropa", fecha: Date.current, paquete: paquete)
    paquete.update_column(:notas_consolidacion, "Meter todo en una sola caja")

    get panel_contexto_url, params: { cliente_id: @cliente.id, tracking: paquete.tracking }

    assert_response :success
    assert_equal 1, response.body.scan("Meter todo en una sola caja").size
  end

  test "un cajero no puede abrir la franja" do
    delete session_url
    login_as users(:cajero)

    get panel_contexto_url, params: { cliente_id: @cliente.id }

    assert_redirected_to root_path
  end
end
