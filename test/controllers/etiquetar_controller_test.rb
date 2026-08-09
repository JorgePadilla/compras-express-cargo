require "test_helper"

class EtiquetarControllerTest < ActionDispatch::IntegrationTest
  setup do
    @digitador = users(:digitador)
    post session_url, params: { email_address: @digitador.email_address, password: "password123" }
    # Casi todos los tests etiquetan, lo cual requiere una sesión de tipo de
    # envío activa. La arrancamos con :express por defecto.
    post iniciar_sesion_etiquetar_url, params: { tipo_envio_id: tipo_envios(:express).id }
  end

  test "should get index" do
    get etiquetar_url
    assert_response :success
  end

  # ── Sesión de etiquetado por tipo de envío ──

  test "index sin sesión muestra el prompt de inicio" do
    delete finalizar_sesion_etiquetar_url
    get etiquetar_url
    assert_response :success
    assert_select "h2", text: /Qué tipo de envío/
    # Las tarjetas muestran la iconografía + significado (igual que pre-alerta).
    assert_select "p", text: /Aéreo express/
  end

  # Regresión: el bloque del banner se duplicó cuatro veces seguidas al mergear
  # `feat/etiquetar-sesion-tercero-calc` a staging (merges criss-cross que
  # resolvían "ambos agregaron" y dejaban dos copias idénticas). Este test
  # falla si vuelve a colarse una segunda copia.
  test "index con sesión activa muestra el banner una sola vez" do
    get etiquetar_url
    assert_response :success
    # Se cuenta el banner por su marca y no los formularios que apuntan a
    # `finalizar_sesion`: desde PR-C6.9 el aviso de "este paquete es de otro
    # tipo de envío" tiene su propio botón para cerrar la sesión, y contar
    # formularios agarraba ese también.
    assert_select "[data-banner=?]", "sesion-activa", count: 1
    assert_select "p", text: "Sesión activa", count: 1
  end

  test "iniciar_sesion fija el tipo y redirige" do
    delete finalizar_sesion_etiquetar_url
    post iniciar_sesion_etiquetar_url, params: { tipo_envio_id: tipo_envios(:cem).id }
    assert_redirected_to etiquetar_path
  end

  test "iniciar_sesion con tipo inválido no arranca sesión" do
    delete finalizar_sesion_etiquetar_url
    post iniciar_sesion_etiquetar_url, params: { tipo_envio_id: 0 }
    assert_redirected_to etiquetar_path
    # sin sesión activa, crear queda bloqueado
    assert_no_difference("Paquete.count") do
      post etiquetar_url, params: { paquete: { tracking: "1Z999NOSESSION1", cliente_id: clientes(:juan).id } }
    end
  end

  test "create usa el tipo de envío de la sesión e ignora el del form" do
    post etiquetar_url, params: { paquete: {
      tracking: "1Z999SESSIONTIPO1",
      cliente_id: clientes(:juan).id,
      tipo_envio_id: tipo_envios(:cem).id, # debe ser ignorado
      peso: 3.0
    } }
    paquete = Paquete.find_by(tracking: "1Z999SESSIONTIPO1")
    assert_equal tipo_envios(:express).id, paquete.tipo_envio_id
  end

  test "create sin sesión activa se rechaza" do
    delete finalizar_sesion_etiquetar_url
    assert_no_difference("Paquete.count") do
      post etiquetar_url, params: { paquete: {
        tracking: "1Z999NOSESSION2", cliente_id: clientes(:juan).id, peso: 2.0
      } }
    end
    assert_redirected_to etiquetar_path
  end

  test "finalizar_sesion limpia la sesión" do
    delete finalizar_sesion_etiquetar_url
    assert_redirected_to etiquetar_path
    get etiquetar_url
    assert_select "h2", text: /Qué tipo de envío/
  end

  test "create asigna tercero_id" do
    post etiquetar_url, params: { paquete: {
      tracking: "1Z999TERCERO001",
      cliente_id: clientes(:juan).id,
      tercero_id: clientes(:maria).id,
      peso: 4.0
    } }
    paquete = Paquete.find_by(tracking: "1Z999TERCERO001")
    assert_equal clientes(:maria).id, paquete.tercero_id
  end

  test "should create paquete" do
    assert_difference("Paquete.count") do
      post etiquetar_url, params: { paquete: {
        tracking: "1Z999NEWTRACK001",
        cliente_id: clientes(:juan).id,
        tipo_envio_id: tipo_envios(:aereo).id,
        peso: 5.0,
        descripcion: "Test package"
      } }
    end
    paquete = Paquete.last
    # PR-C6.22: etiquetar recibe, no empaca. "Empacado dice, y empacado no es
    # lo que sigue... queda aquí en recibido, porque apenas se recibió."
    assert_equal "recibido_miami", paquete.estado
    assert_equal @digitador, paquete.user
    assert_redirected_to etiquetar_url
  end

  test "should not create paquete without tracking" do
    assert_no_difference("Paquete.count") do
      post etiquetar_url, params: { paquete: {
        tracking: "",
        cliente_id: clientes(:juan).id
      } }
    end
    assert_response :unprocessable_entity
  end

  test "should not create paquete without client" do
    assert_no_difference("Paquete.count") do
      post etiquetar_url, params: { paquete: {
        tracking: "1Z999NOCLIENT001"
      } }
    end
    assert_response :unprocessable_entity
  end

  test "cajero cannot access etiquetar" do
    delete session_url
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }
    get etiquetar_url
    assert_redirected_to root_path
  end

  test "admin can access etiquetar" do
    delete session_url
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
    get etiquetar_url
    assert_response :success
  end

  # ── Sub-etiquetas / split (PR-C) ──

  test "create con cantidad_paquetes > 1 divide el tracking en N paquetes" do
    sucursal = sucursales(:miami)
    assert_difference("Paquete.count", 3) do
      post etiquetar_url, params: { paquete: {
        tracking: "1Z999SPLITCTRL001",
        cliente_id: clientes(:juan).id,
        tipo_envio_id: tipo_envios(:aereo).id,
        peso: 5.0,
        cantidad_paquetes: 3,
        sucursal_id: sucursal.id,
        descripcion: "Split test"
      } }
    end

    paquetes = Paquete.where(tracking: "1Z999SPLITCTRL001").order(:numero_caja)
    assert_equal [ 1, 2, 3 ], paquetes.map(&:numero_caja)
    assert paquetes.all? { |p| p.cantidad_paquetes == 3 }
    assert paquetes.all? { |p| p.estado == "recibido_miami" }
    assert_redirected_to etiquetar_url
  end

  test "create con cantidad_paquetes = 1 crea solo 1 paquete (no split)" do
    assert_difference("Paquete.count", 1) do
      post etiquetar_url, params: { paquete: {
        tracking: "1Z999SINGLECTRL001",
        cliente_id: clientes(:juan).id,
        cantidad_paquetes: 1
      } }
    end
  end

  # Reconciliación: si ya existe un paquete pre_alerta_estado con ese
  # tracking (creado eager desde una pre-alerta), se transiciona en lugar
  # de crear uno nuevo. Esto evita duplicados al etiquetar la caja física.
  test "create reconciles with existing pre_alerta_estado paquete instead of duplicating" do
    pa = PreAlerta.create!(
      cliente: clientes(:juan),
      tipo_envio: tipo_envios(:cer),
      titulo: "Reconcile test",
      creado_por_tipo: "cliente",
      creado_por_id: clientes(:juan).id,
      pre_alerta_paquetes_attributes: [
        { tracking: "RECONCILE001", descripcion: "Original from PA" }
      ]
    )
    esperado = pa.pre_alerta_paquetes.first.paquete
    assert_equal "pre_alerta_estado", esperado.estado

    assert_no_difference -> { Paquete.count } do
      post etiquetar_url, params: { paquete: {
        tracking: "RECONCILE001",
        cliente_id: clientes(:juan).id,
        tipo_envio_id: tipo_envios(:cer).id,
        peso: 7.5,
        descripcion: "Updated by digitador"
      } }
    end

    esperado.reload
    assert_equal "recibido_miami", esperado.estado
    assert_equal 7.5, esperado.peso.to_f
    assert_equal "Updated by digitador", esperado.descripcion
  end
end
