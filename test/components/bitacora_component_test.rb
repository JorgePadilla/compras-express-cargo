require "test_helper"

class BitacoraComponentTest < ViewComponent::TestCase
  setup do
    @user = users(:admin)
    @session = @user.sessions.create!(user_agent: "test", ip_address: "127.0.0.1")
    Current.session = @session
  end

  teardown do
    Current.session = nil
  end

  test "no renderiza si el rol no puede ver audit log" do
    Current.session = nil
    paquete = paquetes(:recibido)
    render_inline(BitacoraComponent.new(record: paquete, label: "del paquete"))
    assert_empty page.text.strip
  end

  test "renderiza summary con count de eventos para admin" do
    paquete = paquetes(:recibido)
    render_inline(BitacoraComponent.new(record: paquete, label: "del paquete"))
    assert_text "Bitácora del paquete"
    assert_text(/\d+ evento/)
  end

  test "muestra mensaje vacío si no hay versions" do
    PaperTrail.request(whodunnit: @user.id) do
      paquete = Paquete.create!(
        cliente: clientes(:juan),
        sucursal: sucursales(:miami),
        tracking: "BITACORA-TEST-EMPTY-#{SecureRandom.hex(3)}"
      )
      paquete.versions.destroy_all
      render_inline(BitacoraComponent.new(record: paquete, label: "del paquete"))
      assert_text "Aún no hay registros"
    end
  end

  test "renderiza evento create con texto 'creó'" do
    PaperTrail.request(whodunnit: @user.id) do
      paquete = Paquete.create!(
        cliente: clientes(:juan),
        sucursal: sucursales(:miami),
        tracking: "BITACORA-TEST-CREATE-#{SecureRandom.hex(3)}"
      )
      render_inline(BitacoraComponent.new(record: paquete, label: "del paquete"))
      assert_text "creó del paquete"
    end
  end

  test "renderiza cambio de estado destacado con uppercase y badge" do
    PaperTrail.request(whodunnit: @user.id) do
      paquete = Paquete.create!(
        cliente: clientes(:juan),
        sucursal: sucursales(:miami),
        tracking: "BITACORA-TEST-ESTADO-#{SecureRandom.hex(3)}",
        estado: "recibido_miami",
        fecha_recibido_miami: 1.hour.ago
      )
      paquete.update!(estado: "empacado")
      render_inline(BitacoraComponent.new(record: paquete, label: "del paquete"))
      assert_text "cambió estado"
      # El badge muestra el estado humanizado
      assert_text(/Empacado/i)
    end
  end

  test "audit_column_label traduce nombres de columna conocidos" do
    helper = Class.new { include AuditLogHelper }.new
    assert_equal "Notas de consolidación", helper.audit_column_label("notas_consolidacion")
    assert_equal "Cliente", helper.audit_column_label("cliente_id")
    # Fallback humanize para columnas sin entrada en el dict.
    assert_equal "Foo bar", helper.audit_column_label("foo_bar")
  end
end
