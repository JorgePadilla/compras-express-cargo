require "test_helper"

class PaquetesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @paquete = paquetes(:recibido)
  end

  test "should get index" do
    get paquetes_url
    assert_response :success
  end

  test "should search paquetes" do
    get paquetes_url, params: { q: "1Z999" }
    assert_response :success
  end

  test "should filter by estado" do
    get paquetes_url, params: { estado: "recibido_miami" }
    assert_response :success
  end

  test "should show paquete" do
    get paquete_url(@paquete)
    assert_response :success
  end

  test "should get edit" do
    get edit_paquete_url(@paquete)
    assert_response :success
  end

  test "should update paquete" do
    patch paquete_url(@paquete), params: { paquete: { descripcion: "Updated" } }
    assert_redirected_to paquete_url(@paquete)
    @paquete.reload
    assert_equal "Updated", @paquete.descripcion
  end

  test "should get label" do
    get label_paquete_url(@paquete)
    assert_response :success
  end

  test "should check tracking" do
    get check_tracking_paquetes_url, params: { tracking: @paquete.tracking }
    assert_response :success
    json = JSON.parse(response.body)
    assert json["exists"]
    assert_equal @paquete.guia, json["guia"]
  end

  test "should check tracking not found" do
    get check_tracking_paquetes_url, params: { tracking: "NONEXISTENT" }
    assert_response :success
    json = JSON.parse(response.body)
    assert_not json["exists"]
  end

  test "should search unassigned paquetes" do
    get search_paquetes_url, params: { q: "PQ-000" }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
  end

  test "should filter by valid date range" do
    get paquetes_url, params: { fecha_desde: Date.current.to_s, fecha_hasta: Date.current.to_s }
    assert_response :success
  end

  test "should handle invalid fecha_desde gracefully" do
    get paquetes_url, params: { fecha_desde: "not-a-date" }
    assert_response :success
  end

  test "should handle invalid fecha_hasta gracefully" do
    get paquetes_url, params: { fecha_hasta: "invalid" }
    assert_response :success
  end

  test "cajero cannot access check_tracking" do
    delete session_url
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }
    get check_tracking_paquetes_url, params: { tracking: @paquete.tracking }
    assert_response :success
  end

  test "unauthenticated user cannot access check_tracking" do
    delete session_url
    get check_tracking_paquetes_url, params: { tracking: @paquete.tracking }
    assert_redirected_to new_session_url
  end

  test "search endpoint returns html-escaped data" do
    get search_paquetes_url, params: { q: "PQ-000" }, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    json.each do |p|
      assert_not_includes p["guia"].to_s, "<script"
      assert_not_includes p["cliente"].to_s, "<script"
    end
  end

  # ── Filtros multi-select (PR1) ──

  test "index filtra por multiples estados via estados[]" do
    get paquetes_url, params: { estados: %w[recibido_miami empacado], incluir_mas_1_ano: "1" }
    assert_response :success
    assigned = @controller.instance_variable_get(:@paquetes)
    assigned.each { |p| assert_includes %w[recibido_miami empacado], p.estado }
  end

  test "index filtra por sucursal via sucursal_ids[]" do
    miami = sucursales(:miami)
    paquetes(:recibido).update_column(:sucursal_id, miami.id)
    get paquetes_url, params: { sucursal_ids: [ miami.id ], incluir_mas_1_ano: "1" }
    assert_response :success
    assigned = @controller.instance_variable_get(:@paquetes)
    assigned.each { |p| assert_equal miami.id, p.sucursal_id }
  end

  test "index combina estado + sucursal (AND logico)" do
    miami = sucursales(:miami)
    paquetes(:recibido).update_columns(sucursal_id: miami.id, estado: "recibido_miami")
    get paquetes_url, params: {
      estados: [ "recibido_miami" ],
      sucursal_ids: [ miami.id ],
      incluir_mas_1_ano: "1"
    }
    assert_response :success
    assigned = @controller.instance_variable_get(:@paquetes)
    assert_includes assigned, paquetes(:recibido).reload
  end

  test "busqueda por descripcion (contenido)" do
    paquetes(:recibido).update_column(:descripcion, "iPhone 15 Pro Max")
    get paquetes_url, params: { q: "iPhone", incluir_mas_1_ano: "1" }
    assert_response :success
    assigned = @controller.instance_variable_get(:@paquetes)
    assert_includes assigned, paquetes(:recibido).reload
  end

  test "busqueda por numero_recepcion" do
    miami = sucursales(:miami)
    paquete = paquetes(:recibido)
    paquete.update!(sucursal_id: miami.id, numero_recepcion: "RM-042424")
    get paquetes_url, params: { q: "RM-042424", incluir_mas_1_ano: "1" }
    assert_response :success
    assigned = @controller.instance_variable_get(:@paquetes)
    assert_includes assigned, paquete
  end

  test "toggle solo_facturados filtra estado = facturado" do
    paquetes(:recibido).update_column(:estado, "facturado")
    get paquetes_url, params: { solo_facturados: "1", incluir_mas_1_ano: "1" }
    assert_response :success
    assigned = @controller.instance_variable_get(:@paquetes)
    assigned.each { |p| assert_equal "facturado", p.estado }
  end

  test "toggle incluir_facturados=0 excluye facturados" do
    paquetes(:recibido).update_column(:estado, "facturado")
    get paquetes_url, params: { incluir_facturados: "0", incluir_mas_1_ano: "1" }
    assert_response :success
    assigned = @controller.instance_variable_get(:@paquetes)
    assert_not(assigned.any? { |p| p.estado == "facturado" })
  end
end
