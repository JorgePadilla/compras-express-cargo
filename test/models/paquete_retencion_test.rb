require "test_helper"

# PR-D2: validación retencion_requiere_motivo_o_notas — al pasar a
# estado=retenido el paquete debe tener al menos un motivo o
# notas_retencion con detalle.
class PaqueteRetencionTest < ActiveSupport::TestCase
  setup do
    @cliente  = clientes(:juan)
    @sucursal = sucursales(:miami)
    @motivo   = MotivoRetencion.create!(nombre: "Test - Daño visible")
  end

  test "puede pasar a retenido con notas_retencion" do
    p = Paquete.create!(tracking: "1Z999RTN_A", cliente: @cliente, sucursal: @sucursal)
    p.estado = "retenido"
    p.notas_retencion = "Llegó con la caja rota"
    assert p.valid?, p.errors.full_messages.join(", ")
  end

  test "puede pasar a retenido con motivos seleccionados" do
    p = Paquete.create!(tracking: "1Z999RTN_B", cliente: @cliente, sucursal: @sucursal)
    p.motivos_retencion << @motivo
    p.estado = "retenido"
    assert p.valid?
  end

  test "no puede pasar a retenido sin motivos ni notas" do
    p = Paquete.create!(tracking: "1Z999RTN_C", cliente: @cliente, sucursal: @sucursal)
    p.estado = "retenido"
    assert_not p.valid?
    assert p.errors[:notas_retencion].any?
  end

  test "estados que no son retenido no requieren motivo/notas" do
    p = Paquete.new(tracking: "1Z999RTN_D", cliente: @cliente, sucursal: @sucursal,
                    estado: "empacado")
    assert p.valid?, "empacado no debería requerir notas_retencion"
  end

  test "notas_retencion en blanco (whitespace) no satisface la validación" do
    p = Paquete.create!(tracking: "1Z999RTN_E", cliente: @cliente, sucursal: @sucursal)
    p.estado = "retenido"
    p.notas_retencion = "   \n  "
    assert_not p.valid?
  end
end
