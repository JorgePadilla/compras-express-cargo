require "test_helper"

# PR-D1.a: confirma que paper_trail está activo en los modelos clave y
# que captura `whodunnit` desde Current.user.
class PaperTrailAuditTest < ActiveSupport::TestCase
  setup do
    PaperTrail.request.whodunnit = users(:admin).id
  end

  teardown do
    PaperTrail.request.whodunnit = nil
  end

  test "Paquete tiene paper_trail" do
    p = Paquete.create!(tracking: "1Z999PT_A", cliente: clientes(:juan), sucursal: sucursales(:miami))
    assert p.versions.any?, "esperaba al menos 1 version (create)"
    assert_equal "create", p.versions.last.event
    assert_equal users(:admin).id.to_s, p.versions.last.whodunnit
  end

  test "Paquete update genera version con object_changes" do
    p = paquetes(:recibido)
    p.update!(descripcion: "Nuevo contenido para audit")
    update_v = p.versions.where(event: "update").last
    assert_not_nil update_v
    changes = update_v.changeset
    assert_includes changes.keys, "descripcion"
    old_val, new_val = changes["descripcion"]
    assert_equal "Nuevo contenido para audit", new_val
  end

  test "Cliente tiene paper_trail" do
    c = clientes(:juan)
    c.update!(telefono: "11223344")  # cambio real (era 99887766 en fixture)
    assert c.versions.where(event: "update").any?
  end

  test "PreAlerta tiene paper_trail" do
    pa = pre_alertas(:activa)
    pa.update!(notas_grupo: "Audit test")
    assert pa.versions.where(event: "update").any?
  end

  test "Manifiesto tiene paper_trail" do
    assert Manifiesto.method_defined?(:versions), "Manifiesto debe tener has_paper_trail"
  end

  test "Venta tiene paper_trail" do
    assert Venta.method_defined?(:versions)
  end

  test "PreFactura tiene paper_trail" do
    assert PreFactura.method_defined?(:versions)
  end

  test "Entrega tiene paper_trail" do
    assert Entrega.method_defined?(:versions)
  end

  test "WarehouseReceipt tiene paper_trail" do
    assert WarehouseReceipt.method_defined?(:versions)
  end

  test "whodunnit es nil cuando no hay usuario en contexto" do
    PaperTrail.request.whodunnit = nil
    p = Paquete.create!(tracking: "1Z999PT_NO_USER", cliente: clientes(:juan), sucursal: sucursales(:miami))
    assert_nil p.versions.last.whodunnit
  end
end
