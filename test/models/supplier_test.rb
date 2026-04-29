require "test_helper"

class SupplierTest < ActiveSupport::TestCase
  test "valid with required fields" do
    supplier = Supplier.new(codigo: "TEST", nombre: "Test Supplier")
    assert supplier.valid?
  end

  test "requires codigo" do
    supplier = Supplier.new(nombre: "X")
    assert_not supplier.valid?
    assert supplier.errors[:codigo].any?
  end

  test "requires nombre" do
    supplier = Supplier.new(codigo: "X")
    assert_not supplier.valid?
    assert supplier.errors[:nombre].any?
  end

  test "codigo is unique case-insensitive" do
    Supplier.create!(codigo: "AMZN", nombre: "Amazon")
    duplicate = Supplier.new(codigo: "amzn", nombre: "Otro")
    assert_not duplicate.valid?
  end

  test "tipo defaults to comercio" do
    supplier = Supplier.new(codigo: "X", nombre: "Y")
    assert_equal "comercio", supplier.tipo
  end

  test "tipo must be in TIPOS list" do
    supplier = Supplier.new(codigo: "X", nombre: "Y", tipo: "invalido")
    assert_not supplier.valid?
  end

  test "entrega_personal? returns true for that tipo" do
    supplier = Supplier.new(codigo: "EP", nombre: "X", tipo: "entrega_personal")
    assert supplier.entrega_personal?
  end

  test "scope activos excluye inactivos" do
    activo   = Supplier.create!(codigo: "A", nombre: "A", activo: true)
    inactivo = Supplier.create!(codigo: "B", nombre: "B", activo: false)
    assert_includes Supplier.activos, activo
    assert_not_includes Supplier.activos, inactivo
  end

  test "codigo se normaliza a mayúsculas" do
    supplier = Supplier.create!(codigo: "abc", nombre: "X")
    assert_equal "ABC", supplier.codigo
  end
end
