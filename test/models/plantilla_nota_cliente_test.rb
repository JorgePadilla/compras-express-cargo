require "test_helper"

class PlantillaNotaClienteTest < ActiveSupport::TestCase
  test "valid con titulo y texto" do
    p = PlantillaNotaCliente.new(titulo: "Test", texto: "Cuerpo")
    assert p.valid?
  end

  test "requires titulo y texto" do
    p = PlantillaNotaCliente.new
    assert_not p.valid?
    assert p.errors[:titulo].any?
    assert p.errors[:texto].any?
  end

  test "scope activas excluye inactivas" do
    activa   = PlantillaNotaCliente.create!(titulo: "A", texto: "x", activo: true)
    inactiva = PlantillaNotaCliente.create!(titulo: "B", texto: "y", activo: false)
    assert_includes PlantillaNotaCliente.activas, activa
    assert_not_includes PlantillaNotaCliente.activas, inactiva
  end

  test "scope ordered respeta position" do
    a = PlantillaNotaCliente.create!(titulo: "Z", texto: "x", position: 0)
    b = PlantillaNotaCliente.create!(titulo: "A", texto: "y", position: 1)
    ordered = PlantillaNotaCliente.ordered.to_a
    assert_equal [ a, b ], ordered.first(2)
  end
end
