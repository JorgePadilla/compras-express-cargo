require "test_helper"

class EtiquetarControllerTest < ActionDispatch::IntegrationTest
  setup do
    @digitador = users(:digitador)
    post session_url, params: { email_address: @digitador.email_address, password: "password123" }
  end

  test "should get index" do
    get etiquetar_url
    assert_response :success
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
    assert_equal "empacado", paquete.estado
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
    assert paquetes.all? { |p| p.estado == "empacado" }
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
    assert_equal "empacado", esperado.estado
    assert_equal 7.5, esperado.peso.to_f
    assert_equal "Updated by digitador", esperado.descripcion
  end
end
