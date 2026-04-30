require "test_helper"

class SubLocalidadTest < ActiveSupport::TestCase
  setup do
    @sucursal = sucursales(:miami)
  end

  test "valid con sucursal + codigo + nombre" do
    s = SubLocalidad.new(sucursal: @sucursal, codigo: "MI01", nombre: "Bodega Miami 1")
    assert s.valid?
  end

  test "requires codigo y nombre" do
    s = SubLocalidad.new(sucursal: @sucursal)
    assert_not s.valid?
    assert s.errors[:codigo].any?
    assert s.errors[:nombre].any?
  end

  test "codigo único por sucursal (no global)" do
    SubLocalidad.create!(sucursal: @sucursal, codigo: "ZR01", nombre: "Test")
    duplicate_misma_sucursal = SubLocalidad.new(sucursal: @sucursal, codigo: "zr01", nombre: "Otro")
    assert_not duplicate_misma_sucursal.valid?

    otra_sucursal = sucursales(:zeron_sps)
    same_codigo_other_sucursal = SubLocalidad.new(sucursal: otra_sucursal, codigo: "ZR01", nombre: "OK")
    assert same_codigo_other_sucursal.valid?, "el mismo código debería estar permitido en otra sucursal"
  end

  test "codigo se normaliza a uppercase" do
    s = SubLocalidad.create!(sucursal: @sucursal, codigo: "mi01", nombre: "X")
    assert_equal "MI01", s.codigo
  end

  test "scope activas excluye inactivas" do
    activa   = SubLocalidad.create!(sucursal: @sucursal, codigo: "AC01", nombre: "A", activo: true)
    inactiva = SubLocalidad.create!(sucursal: @sucursal, codigo: "IN01", nombre: "B", activo: false)
    assert_includes SubLocalidad.activas, activa
    assert_not_includes SubLocalidad.activas, inactiva
  end

  test "to_s combina codigo y nombre" do
    s = SubLocalidad.new(codigo: "ZR01", nombre: "Zerón Central")
    assert_equal "ZR01 · Zerón Central", s.to_s
  end
end
