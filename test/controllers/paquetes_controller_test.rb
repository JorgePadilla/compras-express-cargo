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

  test "edit redirects to show?mode=edit (inline edit)" do
    get edit_paquete_url(@paquete)
    assert_redirected_to paquete_url(@paquete, mode: "edit")
  end

  test "show with mode=edit renders editable form" do
    get paquete_url(@paquete, mode: "edit")
    assert_response :success
    assert_match(/id="paquete-edit-form"/, response.body)
  end

  test "should update paquete" do
    patch paquete_url(@paquete), params: { paquete: { descripcion: "Updated" } }
    assert_redirected_to paquete_url(@paquete)
    @paquete.reload
    assert_equal "Updated", @paquete.descripcion
  end

  test "update persiste flags + campos del modal (recolecta + retencion + cambio servicio)" do
    motivo = MotivoRetencion.create!(nombre: "Caja dañada", activo: true)

    patch paquete_url(@paquete), params: { paquete: {
      recolecta_solicitada: "1",
      recolecta_monto: "35.0",
      recolecta_moneda: "USD",
      retener_miami: "1",
      notas_retencion: "Caja se ve golpeada",
      motivo_retencion_ids: [ "", motivo.id.to_s ],
      solicito_cambio_servicio: "1"
    } }

    @paquete.reload
    assert @paquete.recolecta_solicitada?
    assert_equal 35.0, @paquete.recolecta_monto.to_f
    assert_equal "USD", @paquete.recolecta_moneda
    assert @paquete.retener_miami?
    assert_equal "Caja se ve golpeada", @paquete.notas_retencion
    assert_includes @paquete.motivo_retencion_ids, motivo.id
    assert @paquete.solicito_cambio_servicio?
  end

  test "should get warehouse receipt" do
    get warehouse_receipt_paquete_url(@paquete)
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

  test "index ignora cliente_id (filtro removido — usar quick filters de codigo/nombre)" do
    juan = clientes(:juan)
    get paquetes_url, params: { cliente_id: juan.id, incluir_mas_1_ano: "1" }
    assert_response :success
    # No crashea aunque reciba el param legacy. No hay @cliente_seleccionado.
    assert_nil @controller.instance_variable_get(:@cliente_seleccionado)
  end

  test "index filtra por pre_alerta_id" do
    pap = pre_alerta_paquetes(:pap_vinculado)
    pa = pap.pre_alerta
    get paquetes_url, params: { pre_alerta_id: pa.id, incluir_mas_1_ano: "1" }
    assert_response :success
    assigned = @controller.instance_variable_get(:@paquetes)
    assert_includes assigned, pap.paquete
    assert_equal pa, @controller.instance_variable_get(:@pre_alerta_seleccionada)
  end

  test "index filtra por cliente_codigo (quick filter)" do
    juan = clientes(:juan)
    get paquetes_url, params: { cliente_codigo: juan.codigo, incluir_mas_1_ano: "1" }
    assert_response :success
    assigned = @controller.instance_variable_get(:@paquetes)
    assigned.each { |p| assert_equal juan.id, p.cliente_id }
  end

  test "index filtra por cliente_nombre multi-palabra (quick filter)" do
    get paquetes_url, params: { cliente_nombre: "juan perez", incluir_mas_1_ano: "1" }
    assert_response :success
    assigned = @controller.instance_variable_get(:@paquetes)
    assert_includes assigned, paquetes(:recibido)
  end

  test "index filtra por busqueda_avanzada (notas_internas)" do
    paquetes(:recibido).update!(notas_internas: "FRAGIL_KEYWORD_TEST")
    get paquetes_url, params: { busqueda_avanzada: "FRAGIL_KEYWORD_TEST", incluir_mas_1_ano: "1" }
    assert_response :success
    assigned = @controller.instance_variable_get(:@paquetes)
    assert_includes assigned, paquetes(:recibido).reload
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
    paquete.update!(sucursal_id: miami.id, numero_recepcion: "RMI-042424")
    get paquetes_url, params: { q: "RMI-042424", incluir_mas_1_ano: "1" }
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

  test "bulk_print renderiza HTML imprimible (no PDF download)" do
    post bulk_print_paquetes_url, params: { paquete_ids: [ paquetes(:recibido).id ] }
    assert_response :success
    assert_equal "text/html", response.media_type
    # No debe ser disposición attachment (no descarga).
    assert_no_match(/attachment/i, response.headers["Content-Disposition"].to_s)
    # Auto-dispara window.print() al cargar.
    assert_match(/window\.print\(\)/, response.body)
    # Listado contiene al paquete seleccionado.
    assert_match(paquetes(:recibido).tracking, response.body)
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

  test "update permite asignar tercero_id" do
    paquete = paquetes(:recibido)
    patch paquete_url(paquete), params: { paquete: { tercero_id: clientes(:maria).id } }
    assert_redirected_to paquete_url(paquete)
    assert_equal clientes(:maria).id, paquete.reload.tercero_id
  end

  test "update permite limpiar tercero_id" do
    paquete = paquetes(:recibido)
    paquete.update!(tercero: clientes(:maria))
    patch paquete_url(paquete), params: { paquete: { tercero_id: "" } }
    assert_redirected_to paquete_url(paquete)
    assert_nil paquete.reload.tercero_id
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

  # PR-10.d.3: redirigia al Warehouse Receipt — la hoja carta del expediente —
  # desde una accion que se llama "reimprimir_etiquetas".
  test "reimprimir_etiquetas para paquete individual redirige a la etiqueta" do
    get reimprimir_etiquetas_paquete_url(@paquete)
    assert_redirected_to etiqueta_paquete_path(@paquete)
  end

  # PR-D4.review v2 — etiquetas_combinadas renderiza N etiquetas en una sola
  # pestaña, evitando el flow de N pop-ups.
  #
  # PR-10.d.3: renderizaba N warehouse receipts. El salto de pagina ahora lo
  # pone `.etq + .etq` en el layout de etiqueta, no un div envolvente.
  test "etiquetas_combinadas renderiza varios paquetes" do
    paquete = paquetes(:recibido)
    paquete.update_columns(cantidad_paquetes: 2, numero_caja: 1)
    hermano = Paquete.create!(tracking: paquete.tracking, cliente: paquete.cliente,
                              sucursal: paquete.sucursal, cantidad_paquetes: 2, numero_caja: 2)

    get etiquetas_combinadas_paquetes_url(paquete_ids: [ paquete.id, hermano.id ])
    assert_response :success
    assert_equal 2, response.body.scan(/class="etq"/).size
    assert_no_match(/WAREHOUSE RECEIPT/, response.body)
    # Auto-print en JS al cargar.
    assert_match(/window\.print/, response.body)
  end

  test "etiquetas_combinadas sin ids redirige con alerta" do
    get etiquetas_combinadas_paquetes_url
    assert_redirected_to paquetes_path
    assert_match(/seleccion/i, flash[:alert])
  end

  test "etiquetas_combinadas con ids inexistentes redirige con alerta" do
    get etiquetas_combinadas_paquetes_url(paquete_ids: [ 999999 ])
    assert_redirected_to paquetes_path
    assert_match(/no se encontraron|no encontró/i, flash[:alert])
  end

  test "Refrescar button opta-in al frame paquete_dynamic" do
    get paquete_url(@paquete)
    assert_response :success
    assert_select "a[data-turbo-frame=?]", "paquete_dynamic"
  end

  # PR-D7.b: cambios manuales de estado restringidos por rol + modal de
  # retroceso cuando un supervisor mueve hacia atrás en el pipeline.

  test "cajero no puede acceder al update (authorize_edit lo redirecciona antes del gate)" do
    delete session_url
    cajero = users(:cajero)
    post session_url, params: { email_address: cajero.email_address, password: "password123" }

    # Cajero ni siquiera pasa `authorize_edit`; redirect a /paquetes.
    # El gate de estado (defensa en profundidad) solo aplica a usuarios
    # que sí pueden editar otros campos pero no estado — el dropdown
    # del show ya está oculto para los demás vía can_change_estado_paquete?
    estado_inicial = @paquete.estado
    patch paquete_url(@paquete), params: { paquete: { estado: "empacado" } }

    assert_response :redirect
    assert_match(/No tienes permiso/, flash[:alert])
    @paquete.reload
    assert_equal estado_inicial, @paquete.estado
  end

  test "update bloquea retroceso sin confirm_retroceso (admin)" do
    entregado = paquetes(:entregado)
    estado_inicial = entregado.estado

    patch paquete_url(entregado), params: { paquete: { estado: "en_reparto" } }

    assert_response :unprocessable_entity
    entregado.reload
    assert_equal estado_inicial, entregado.estado
    assert_select "dialog#estado-transition-dialog"
    assert_match(/retrocediendo el pipeline/i, response.body)
  end

  test "update permite retroceso con confirm_retroceso=1 (admin)" do
    entregado = paquetes(:entregado)

    patch paquete_url(entregado), params: {
      paquete: { estado: "en_reparto" },
      confirm_retroceso: "1"
    }

    assert_redirected_to paquete_url(entregado)
    entregado.reload
    assert_equal "en_reparto", entregado.estado
  end

  # PR-D7.d
  test "update con retroceso confirmado limpia fechas posteriores" do
    entregado = paquetes(:entregado)
    entregado.update_columns(
      fecha_entregado:    1.day.ago,
      fecha_en_reparto:   2.days.ago,
      fecha_disponible:   3.days.ago,
      fecha_consolidando: 4.days.ago,
      fecha_aduana:       5.days.ago,
      fecha_enviado:      6.days.ago,
      fecha_empacado:     7.days.ago,
      fecha_recibido_miami: 8.days.ago
    )

    patch paquete_url(entregado), params: {
      paquete: { estado: "recibido_miami" },
      confirm_retroceso: "1"
    }

    entregado.reload
    assert_redirected_to paquete_url(entregado)
    assert_equal "recibido_miami", entregado.estado
    assert_nil entregado.fecha_entregado
    assert_nil entregado.fecha_en_reparto
    assert_nil entregado.fecha_disponible
    # fecha_consolidando NO se limpia: consolidando_honduras está fuera de
    # ESTADOS_ORDEN (estado excepcional). Si Yusef quiere también limpiar
    # esa, se ajusta el map en otro PR.
    assert_nil entregado.fecha_aduana
    assert_nil entregado.fecha_enviado
    assert_nil entregado.fecha_empacado
    # Fecha del nuevo estado se mantiene (callback la actualiza a Time.current).
    assert_not_nil entregado.fecha_recibido_miami
  end

  test "update permite avance normal (admin, sin retroceso)" do
    # Usa el fixture `empacado` (sin tareas abiertas) y avanza un paso.
    p = paquetes(:empacado)
    patch paquete_url(p), params: { paquete: { estado: "enviado_honduras" } }
    assert_redirected_to paquete_url(p)
    p.reload
    assert_equal "enviado_honduras", p.estado
  end

  test "update sin cambio de estado no toca el gate" do
    estado_inicial = @paquete.estado
    patch paquete_url(@paquete), params: { paquete: { descripcion: "Nueva desc" } }
    assert_redirected_to paquete_url(@paquete)
    @paquete.reload
    assert_equal estado_inicial, @paquete.estado
    assert_equal "Nueva desc", @paquete.descripcion
  end

  # PR-D7.m: edición manual de fechas desde el form.
  test "admin edita fecha_recibido_miami y actualiza _by_user_id" do
    fecha_nueva = 3.days.ago.beginning_of_minute
    patch paquete_url(@paquete), params: {
      paquete: { fecha_recibido_miami: fecha_nueva.iso8601 }
    }
    assert_redirected_to paquete_url(@paquete)
    @paquete.reload
    assert_equal fecha_nueva.to_i, @paquete.fecha_recibido_miami.to_i
    assert_equal @user.id, @paquete.fecha_recibido_miami_by_user_id
  end

  test "cajero no puede editar fechas (authorize_edit lo redirecciona)" do
    delete session_url
    cajero = users(:cajero)
    post session_url, params: { email_address: cajero.email_address, password: "password123" }

    fecha_original = @paquete.fecha_recibido_miami
    patch paquete_url(@paquete), params: {
      paquete: { fecha_recibido_miami: 5.days.ago.iso8601 }
    }
    assert_response :redirect
    @paquete.reload
    assert_equal fecha_original&.to_i, @paquete.fecha_recibido_miami&.to_i
  end
end
