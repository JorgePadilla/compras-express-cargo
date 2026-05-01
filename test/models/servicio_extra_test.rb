require "test_helper"

class ServicioExtraTest < ActiveSupport::TestCase
  test "valid con codigo, descripcion y precio_venta" do
    s = ServicioExtra.new(codigo: "TEST", descripcion: "Test", costo: 0, precio_venta: 10, moneda: "USD")
    assert s.valid?
  end

  test "rechaza codigo con espacios o minusculas (formato)" do
    s = ServicioExtra.new(codigo: "test code", descripcion: "x", costo: 0, precio_venta: 1, moneda: "USD")
    assert_not s.valid?
    assert s.errors[:codigo].any?
  end

  test "normaliza codigo a mayúsculas" do
    s = ServicioExtra.create!(codigo: "abc_123", descripcion: "Test", costo: 0, precio_venta: 1, moneda: "USD")
    assert_equal "ABC_123", s.codigo
  end

  test "rechaza codigo duplicado case-insensitive" do
    ServicioExtra.create!(codigo: "DUP_TEST", descripcion: "Test", costo: 0, precio_venta: 1, moneda: "USD")
    dup = ServicioExtra.new(codigo: "dup_test", descripcion: "Test", costo: 0, precio_venta: 1, moneda: "USD")
    assert_not dup.valid?
  end

  test "margen calcula precio_venta - costo" do
    s = ServicioExtra.new(costo: 10, precio_venta: 25)
    assert_equal 15, s.margen
  end

  test "scope activos excluye inactivos" do
    activo = ServicioExtra.create!(codigo: "ACT_TEST", descripcion: "x", costo: 0, precio_venta: 1, moneda: "USD", activo: true)
    inact  = ServicioExtra.create!(codigo: "INA_TEST", descripcion: "x", costo: 0, precio_venta: 1, moneda: "USD", activo: false)
    assert_includes ServicioExtra.activos, activo
    assert_not_includes ServicioExtra.activos, inact
  end

  test "precio_incluye_isv default true" do
    s = ServicioExtra.create!(codigo: "DEF_TEST", descripcion: "x", costo: 0, precio_venta: 1, moneda: "USD")
    assert s.precio_incluye_isv
  end
end
