require "test_helper"

class SucursalTest < ActiveSupport::TestCase
  test "requiere codigo y nombre; el prefijo de recepcion ya no (RP-17)" do
    # Seguimiento de C18-02: el número sale de `codigo`; crear DF México no
    # puede exigir inventar un prefijo que nadie lee.
    s = Sucursal.new
    assert_not s.valid?
    assert_includes s.errors.attribute_names, :codigo
    assert_includes s.errors.attribute_names, :nombre
    assert_not_includes s.errors.attribute_names, :codigo_recepcion_prefix
  end

  test "codigo se normaliza a mayusculas" do
    s = Sucursal.new(codigo: "tst", nombre: "Test", codigo_recepcion_prefix: "rt")
    s.valid?
    assert_equal "TST", s.codigo
    assert_equal "RT", s.codigo_recepcion_prefix
  end

  test "codigo_recepcion_prefix solo permite 1-4 letras" do
    s = Sucursal.new(codigo: "TST", nombre: "Test", codigo_recepcion_prefix: "RT99")
    assert_not s.valid?
    assert_includes s.errors[:codigo_recepcion_prefix].join, "solo mayusculas"
  end

  test "codigo es unico (case-insensitive)" do
    Sucursal.create!(codigo: "FOO", nombre: "Foo", codigo_recepcion_prefix: "RFO")
    dup = Sucursal.new(codigo: "foo", nombre: "Dup", codigo_recepcion_prefix: "RDP")
    assert_not dup.valid?
    assert_includes dup.errors.attribute_names, :codigo
  end

  test "scope activas excluye inactivas" do
    Sucursal.create!(codigo: "INA", nombre: "Inactiva", codigo_recepcion_prefix: "RIA", activo: false)
    activas = Sucursal.activas
    assert_includes activas, sucursales(:miami)
    assert_not_includes activas, Sucursal.find_by(codigo: "INA")
  end
end
