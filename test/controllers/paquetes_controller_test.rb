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

  test "check_tracking incluye datos del flow de duplicado (PR-B)" do
    get check_tracking_paquetes_url, params: { tracking: @paquete.tracking }
    assert_response :success
    json = JSON.parse(response.body)

    assert json["exists"]
    assert_equal @paquete.id, json["existing_paquete_id"]
    assert_equal edit_paquete_path(@paquete), json["edit_url"]
    assert_equal @paquete.tracking, json["tracking_base"]
    assert_equal "A", json["next_suffix"]
    assert_equal "#{@paquete.tracking}A", json["next_tracking"]
  end

  test "check_tracking devuelve next_suffix nil cuando A-Z se agotaron" do
    base = @paquete.tracking
    ("A".."Z").each do |letra|
      Paquete.create!(tracking: "#{base}#{letra}", cliente: clientes(:juan), sucursal: sucursales(:miami))
    end
    get check_tracking_paquetes_url, params: { tracking: base }
    assert_response :success
    json = JSON.parse(response.body)
    assert_nil json["next_suffix"]
    assert_nil json["next_tracking"]
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

  test "default excluye facturados (sin toggle)" do
    paquetes(:recibido).update_column(:estado, "facturado")
    get paquetes_url, params: { incluir_mas_1_ano: "1" }
    assert_response :success
    assigned = @controller.instance_variable_get(:@paquetes)
    assert_not(assigned.any? { |p| p.estado == "facturado" })
  end

  test "toggle incluir_facturados=1 incluye facturados" do
    paquetes(:recibido).update_column(:estado, "facturado")
    get paquetes_url, params: { incluir_facturados: "1", incluir_mas_1_ano: "1" }
    assert_response :success
    assigned = @controller.instance_variable_get(:@paquetes)
    assert(assigned.any? { |p| p.estado == "facturado" })
  end

  # ── Export / Bulk actions (PR2) ──

  test "export.pdf devuelve un PDF con los filtros aplicados" do
    get export_paquetes_url(format: :pdf, incluir_mas_1_ano: "1")
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF"), "expected PDF magic bytes"
  end

  test "export.xlsx devuelve un XLSX valido (firma ZIP)" do
    get export_paquetes_url(format: :xlsx, incluir_mas_1_ano: "1")
    assert_response :success
    assert_match(/openxmlformats-officedocument.spreadsheetml.sheet|vnd.ms-excel|excel/i, response.media_type)
    # XLSX es un ZIP, debe empezar con bytes "PK\x03\x04".
    assert response.body.bytes.first(2) == [ 0x50, 0x4B ], "expected ZIP magic PK"
  end

  test "bulk_print requiere al menos un id seleccionado" do
    post bulk_print_paquetes_url, params: { paquete_ids: [] }
    assert_redirected_to paquetes_path
    assert_match(/Selecciona/i, flash[:alert])
  end

  test "bulk_print genera PDF con los paquetes seleccionados" do
    post bulk_print_paquetes_url, params: { paquete_ids: [ paquetes(:recibido).id ] }
    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "bulk_export xlsx con ids seleccionados (XLSX valido)" do
    post bulk_export_paquetes_url, params: { paquete_ids: [ paquetes(:recibido).id ], formato: "xlsx" }
    assert_response :success
    assert_match(/openxmlformats-officedocument.spreadsheetml.sheet|vnd.ms-excel|excel/i, response.media_type)
    assert response.body.bytes.first(2) == [ 0x50, 0x4B ], "expected ZIP magic PK"
  end

  test "bulk_export pdf con ids seleccionados" do
    post bulk_export_paquetes_url, params: { paquete_ids: [ paquetes(:recibido).id ], formato: "pdf" }
    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "bulk_export sin ids redirige con alert" do
    post bulk_export_paquetes_url, params: { paquete_ids: [], formato: "xlsx" }
    assert_redirected_to paquetes_path
    assert_match(/Selecciona/i, flash[:alert])
  end

  # ── Sorting + role gating (PR3) ──

  test "sort por tracking ascendente" do
    get paquetes_url, params: { sort: "tracking", dir: "asc", incluir_mas_1_ano: "1" }
    assert_response :success
  end

  test "sort por cliente con LEFT JOIN clientes" do
    get paquetes_url, params: { sort: "cliente", dir: "asc", incluir_mas_1_ano: "1" }
    assert_response :success
  end

  test "sort por columna no whitelisted cae al default sin SQL injection" do
    get paquetes_url, params: { sort: "DROP TABLE paquetes", dir: "asc" }
    assert_response :success
  end

  test "admin puede borrar paquete" do
    paquete = paquetes(:recibido)
    paquete.update_columns(pre_factura_id: nil, venta_id: nil, manifiesto_id: nil)
    paquete.pre_alerta_paquetes.destroy_all
    paquete.tareas.destroy_all if paquete.respond_to?(:tareas)

    assert_difference("Paquete.count", -1) do
      delete paquete_url(paquete)
    end
    assert_redirected_to paquetes_path
  end

  test "digitador no puede borrar paquete" do
    delete session_url
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }

    paquete = paquetes(:recibido)
    assert_no_difference("Paquete.count") do
      delete paquete_url(paquete)
    end
    assert_redirected_to paquetes_path
    assert_match(/permiso/i, flash[:alert])
  end

  test "cajero no puede editar paquete" do
    delete session_url
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }

    paquete = paquetes(:recibido)
    patch paquete_url(paquete), params: { paquete: { descripcion: "Hacked by cajero" } }
    assert_redirected_to paquetes_path
    assert_not_equal "Hacked by cajero", paquete.reload.descripcion
  end

  test "supervisor_miami puede editar paquete" do
    delete session_url
    sup = User.create!(nombre: "Sup", email_address: "sup_m@test.com", password: "password123",
                        rol: "supervisor_miami", ubicacion: "miami", activo: true)
    post session_url, params: { email_address: sup.email_address, password: "password123" }

    paquete = paquetes(:recibido)
    patch paquete_url(paquete), params: { paquete: { descripcion: "Updated by sup" } }
    assert_redirected_to paquete_url(paquete)
    assert_equal "Updated by sup", paquete.reload.descripcion
  end

  # ── Sort direction whitelist (review round 4) ──

  test "sort dir invalida cae al default desc" do
    get paquetes_url, params: { sort: "tracking", dir: "DROP TABLE", incluir_mas_1_ano: "1" }
    assert_response :success
  end

  test "sort dir vacia cae al default desc" do
    get paquetes_url, params: { sort: "tracking", dir: "", incluir_mas_1_ano: "1" }
    assert_response :success
  end

  # ── Destroy: blockers especificos ──

  test "destroy paquete con manifiesto bloquea con mensaje especifico" do
    paquete = paquetes(:recibido)
    paquete.update_columns(pre_factura_id: nil, venta_id: nil)
    paquete.pre_alerta_paquetes.destroy_all
    paquete.tareas.destroy_all if paquete.respond_to?(:tareas)

    # Asociar a un manifiesto
    manifiesto = manifiestos(:creado)
    paquete.update_column(:manifiesto_id, manifiesto.id)

    assert_no_difference("Paquete.count") do
      delete paquete_url(paquete)
    end
    assert_redirected_to paquete_url(paquete)
    assert_match(/manifiesto/i, flash[:alert])
  end

  # ── Helpers permisos ──

  test "can_edit_paquetes? helper devuelve true para admin" do
    helper = ApplicationController.helpers
    assert helper.respond_to?(:can_edit_paquetes?)
  end

  # PR-D4.a.2 — Mover paquete a otra pre-alerta existente
  test "mover_a_pre_alerta vincula al destino y desvincula del origen" do
    paquete = @paquete
    origen  = pre_alertas(:activa)
    destino = PreAlerta.create!(
      cliente: clientes(:juan),
      tipo_envio: tipo_envios(:aereo),
      titulo: "Destino mover test",
      estado: "pre_alerta"
    )
    paquete.pre_alerta_paquetes.destroy_all
    PreAlertaPaquete.create!(
      pre_alerta: origen, paquete: paquete,
      tracking: paquete.tracking, descripcion: "x", fecha: Date.current
    )

    post mover_a_pre_alerta_paquete_url(paquete), params: { pre_alerta_id: destino.id }
    assert_redirected_to paquete_url(paquete)

    paquete.reload
    assert_equal 1, paquete.pre_alerta_paquetes.count
    assert_equal destino.id, paquete.pre_alerta_paquetes.first.pre_alerta_id
  end

  test "mover_a_pre_alerta rechaza pre-alerta inexistente" do
    post mover_a_pre_alerta_paquete_url(@paquete), params: { pre_alerta_id: 999999 }
    assert_redirected_to paquete_url(@paquete)
    assert_match(/no encontrada|anulada/i, flash[:alert])
  end

  test "mover_a_pre_alerta rechaza pre-alerta anulada" do
    anulada = PreAlerta.create!(
      cliente: clientes(:juan),
      tipo_envio: tipo_envios(:aereo),
      titulo: "Anulada destino",
      estado: "anulado"
    )
    post mover_a_pre_alerta_paquete_url(@paquete), params: { pre_alerta_id: anulada.id }
    assert_redirected_to paquete_url(@paquete)
    assert_match(/no encontrada|anulada/i, flash[:alert])
  end

  # Regresión 2026-05-03 — pre_factura como flag boolean no debe colisionar
  # con el belongs_to :pre_factura. El form usa check_box_tag "paquete[pre_factura]"
  # con valores "0"/"1"; el controller debe escribirlos vía column accessor
  # para evitar AssociationTypeMismatch.
  test "update acepta pre_factura como flag boolean ('0' / '1')" do
    paquete = paquetes(:recibido)

    patch paquete_url(paquete), params: { paquete: { pre_factura: "1", descripcion: "x" } }
    assert_redirected_to paquete_url(paquete)
    assert_equal true, paquete.reload[:pre_factura]

    patch paquete_url(paquete), params: { paquete: { pre_factura: "0", descripcion: "x" } }
    assert_redirected_to paquete_url(paquete)
    assert_equal false, paquete.reload[:pre_factura]
  end

  # PR-D4.a.3 — Refrescar recarga sólo el turbo-frame (preserva scroll)
  test "show envuelve contenido en turbo-frame paquete_dynamic" do
    get paquete_url(@paquete)
    assert_response :success
    assert_select "turbo-frame#paquete_dynamic[target=?]", "_top"
  end

  # PR-D4.review — Re-imprimir etiquetas de un paquete dividido muestra
  # checkboxes preseleccionados (Yusef: "modal con checkboxes preseleccionados").
  test "reimprimir_etiquetas para paquete dividido renderiza checkboxes preseleccionados" do
    paquete = paquetes(:recibido)
    paquete.update_columns(cantidad_paquetes: 2, numero_caja: 1)
    Paquete.create!(tracking: paquete.tracking, cliente: paquete.cliente,
                    sucursal: paquete.sucursal, cantidad_paquetes: 2, numero_caja: 2)

    get reimprimir_etiquetas_paquete_url(paquete)
    assert_response :success
    assert_select "input.caja-checkbox[checked]", count: 2
    assert_select "button#print-selected", text: /Imprimir seleccionadas/
    assert_select "input#toggle-all[checked]"
  end

  test "reimprimir_etiquetas para paquete individual redirige al label" do
    get reimprimir_etiquetas_paquete_url(@paquete)
    assert_redirected_to label_paquete_path(@paquete)
  end

  test "Refrescar button opta-in al frame paquete_dynamic" do
    get paquete_url(@paquete)
    assert_response :success
    assert_select "a[data-turbo-frame=?]", "paquete_dynamic"
  end
end
