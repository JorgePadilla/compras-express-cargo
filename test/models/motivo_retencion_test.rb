require "test_helper"

class MotivoRetencionTest < ActiveSupport::TestCase
  test "valid con nombre" do
    m = MotivoRetencion.new(nombre: "Test motivo")
    assert m.valid?
  end

  test "nombre único case-insensitive" do
    # Nota: Postgres LOWER() en la collation actual no convierte Ñ→ñ,
    # por eso evitamos esa letra en el caso de prueba.
    MotivoRetencion.create!(nombre: "Paquete dropeado test")
    duplicate = MotivoRetencion.new(nombre: "PAQUETE DROPEADO TEST")
    assert_not duplicate.valid?
  end

  test "scope activos excluye inactivos" do
    activo   = MotivoRetencion.create!(nombre: "Test activo",   activo: true)
    inactivo = MotivoRetencion.create!(nombre: "Test inactivo", activo: false)
    assert_includes MotivoRetencion.activos, activo
    assert_not_includes MotivoRetencion.activos, inactivo
  end
end
