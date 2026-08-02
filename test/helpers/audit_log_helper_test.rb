require "test_helper"

class AuditLogHelperTest < ActionView::TestCase
  include AuditLogHelper

  test "audit_event_label traduce eventos comunes" do
    assert_equal "creó", audit_event_label("create")
    assert_equal "actualizó", audit_event_label("update")
    assert_equal "eliminó", audit_event_label("destroy")
    assert_equal "rare_event", audit_event_label("rare_event")
  end

  test "audit_value formatea distintos tipos" do
    assert_equal "—", audit_value(nil)
    assert_equal "(vacío)", audit_value("")
    assert_equal "hola", audit_value("hola")
    long_text = "x" * 100
    assert audit_value(long_text).length <= 41 # 40 + ellipsis "..."
  end

  test "audit_users_index resuelve users por whodunnit" do
    user = users(:admin)
    fake_version = Struct.new(:whodunnit).new(user.id.to_s)
    result = audit_users_index([ fake_version ])
    assert_equal user, result[user.id.to_s]
  end

  test "audit_users_index con versions vacío devuelve hash vacío" do
    assert_equal({}, audit_users_index([]))
    assert_equal({}, audit_users_index(nil))
  end

  test "audit_user_for devuelve nil cuando whodunnit es blank" do
    fake_version = Struct.new(:whodunnit).new("")
    assert_nil audit_user_for(fake_version)
  end

  test "audit_changes_summary formatea cambios humanamente" do
    PaperTrail.request.whodunnit = users(:admin).id
    p = paquetes(:recibido)
    p.update!(descripcion: "Nuevo X")
    update_v = p.versions.where(event: "update").last
    summary = audit_changes_summary(update_v)
    assert_includes summary, "descripcion:"
    assert_includes summary, "Nuevo X"
  ensure
    PaperTrail.request.whodunnit = nil
  end

  test "audit_changes_summary excluye timestamps ruidosos" do
    PaperTrail.request.whodunnit = users(:admin).id
    p = paquetes(:recibido)
    p.update!(descripcion: "Test123")
    update_v = p.versions.where(event: "update").last
    summary = audit_changes_summary(update_v)
    assert_not_includes summary, "updated_at"
  ensure
    PaperTrail.request.whodunnit = nil
  end

  # ── Edge cases en audit_changes_summary ──

  test "audit_changes_summary maneja cambio a nil (campo borrado)" do
    PaperTrail.request.whodunnit = users(:admin).id
    p = Paquete.create!(tracking: "1Z999AUDIT_NIL", cliente: clientes(:juan),
                        sucursal: sucursales(:miami), descripcion: "antes")
    p.update!(descripcion: nil)
    summary = audit_changes_summary(p.versions.where(event: "update").last)
    assert_includes summary, "antes"
    assert_includes summary, "—"  # audit_value(nil) → "—"
  ensure
    PaperTrail.request.whodunnit = nil
  end

  test "audit_changes_summary maneja cambio desde empty string" do
    PaperTrail.request.whodunnit = users(:admin).id
    p = Paquete.create!(tracking: "1Z999AUDIT_EMPTY", cliente: clientes(:juan),
                        sucursal: sucursales(:miami), descripcion: "")
    p.update!(descripcion: "lleno")
    summary = audit_changes_summary(p.versions.where(event: "update").last)
    assert_includes summary, "(vacío)"  # audit_value("") → "(vacío)"
    assert_includes summary, "lleno"
  ensure
    PaperTrail.request.whodunnit = nil
  end

  test "audit_changes_summary trunca strings muy largos a 40 chars" do
    PaperTrail.request.whodunnit = users(:admin).id
    long_str = "x" * 80
    p = Paquete.create!(tracking: "1Z999AUDIT_LONG", cliente: clientes(:juan),
                        sucursal: sucursales(:miami), descripcion: "antes")
    p.update!(descripcion: long_str)
    summary = audit_changes_summary(p.versions.where(event: "update").last)
    refute_match(/x{80}/, summary, "el string de 80x no debe aparecer entero")
    assert_match(/x{1,45}/, summary, "debe haber al menos algunos x truncados")
  ensure
    PaperTrail.request.whodunnit = nil
  end

  test "audit_changes_summary maneja cambios booleanos" do
    PaperTrail.request.whodunnit = users(:admin).id
    p = Paquete.create!(tracking: "1Z999AUDIT_BOOL", cliente: clientes(:juan),
                        sucursal: sucursales(:miami), pre_alerta: false)
    p.update!(pre_alerta: true)
    summary = audit_changes_summary(p.versions.where(event: "update").last)
    assert_includes summary, "pre_alerta:"
    assert_includes summary, "true"
    assert_includes summary, "false"
  ensure
    PaperTrail.request.whodunnit = nil
  end

  # ── can_view_audit_log? ──

  test "can_view_audit_log? true para admin" do
    set_current_user(users(:admin))
    assert can_view_audit_log?
  ensure
    Current.session = nil
  end

  test "can_view_audit_log? true para supervisor_miami" do
    set_current_user(User.new(rol: "supervisor_miami"))
    assert can_view_audit_log?
  ensure
    Current.session = nil
  end

  test "can_view_audit_log? false para cajero/sac/digitador" do
    %w[cajero sac digitador_miami entrega_despacho].each do |rol|
      set_current_user(User.new(rol: rol))
      assert_not can_view_audit_log?, "rol #{rol} no debería ver bitácora"
    end
  ensure
    Current.session = nil
  end

  test "can_view_audit_log? false sin user" do
    Current.session = nil
    assert_not can_view_audit_log?
  end

  # ── PR-D7.b: COLUMN_LABELS y FK_RESOLVERS expandidos para los modelos
  #    Cliente, PreAlerta, PreFactura, Venta, Manifiesto, Entrega.

  test "audit_column_label resuelve labels de cliente" do
    assert_equal "Nombre",       audit_column_label("nombre")
    assert_equal "Email",        audit_column_label("email")
    assert_equal "Teléfono",     audit_column_label("telefono")
    assert_equal "Categoría de precios", audit_column_label("categoria_precio_id")
  end

  test "audit_column_label resuelve labels de pre_alerta y pre_factura" do
    assert_equal "N° Documento",       audit_column_label("numero_documento")
    assert_equal "Con re-empaque",     audit_column_label("con_reempaque")
    assert_equal "Tasa de cambio aplicada", audit_column_label("tasa_cambio_aplicada")
    assert_equal "Confirmado en",      audit_column_label("confirmado_at")
  end

  test "audit_column_label resuelve labels de manifiesto y entrega" do
    assert_equal "Empresa transportadora", audit_column_label("empresa_manifiesto_id")
    assert_equal "Sucursal origen",        audit_column_label("sucursal_origen_id")
    assert_equal "Repartidor",             audit_column_label("repartidor_id")
    assert_equal "Tipo de entrega",        audit_column_label("tipo_entrega")
    assert_equal "Despachado en",          audit_column_label("despachado_at")
  end

  test "audit_column_label cae a humanize para columnas no listadas" do
    assert_equal "Columna inventada", audit_column_label("columna_inventada")
  end

  test "FK_RESOLVERS incluye todos los nuevos resolvers" do
    %w[entrega_id tercero_id creado_por_id repartidor_id categoria_precio_id
       empresa_manifiesto_id financiamiento_id sucursal_origen_id].each do |col|
      assert AuditLogHelper::FK_RESOLVERS.key?(col), "falta resolver para #{col}"
    end
  end

  test "tercero_id resolver retorna codigo + nombre del cliente" do
    cliente = clientes(:juan)
    resolver = AuditLogHelper::FK_RESOLVERS["tercero_id"]
    result = resolver.call([ cliente.id ])
    assert_includes result[cliente.id], cliente.codigo
    assert_includes result[cliente.id], cliente.nombre_completo
  end

  private

  # Helper para tests: Current.user es un delegate de Current.session.user,
  # así que hay que asignar un objeto que responda a `:user`.
  def set_current_user(user)
    Current.session = Struct.new(:user).new(user)
  end
end
