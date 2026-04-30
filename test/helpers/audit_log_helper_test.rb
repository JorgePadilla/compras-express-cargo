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
end
