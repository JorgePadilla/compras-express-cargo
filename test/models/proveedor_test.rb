require "test_helper"

class ProveedorTest < ActiveSupport::TestCase
  test "valid con nombre y tipo" do
    p = Proveedor.new(nombre: "Test Comercio", tipo: "comercio")
    assert p.valid?
  end

  test "auto-genera codigo de 3 letras desde nombre" do
    p = Proveedor.create!(nombre: "Zatarain Foods", tipo: "comercio")
    assert_equal "ZAT", p.codigo
  end

  test "auto-genera codigo único agregando sufijo en colisión" do
    Proveedor.create!(nombre: "Zatatest A", tipo: "comercio") # ZAT
    Proveedor.create!(nombre: "Zatatest B", tipo: "comercio") # ZAT2
    tercero = Proveedor.create!(nombre: "Zatatest C", tipo: "comercio")
    assert_match(/\AZAT\d+\z/, tercero.codigo)
  end

  test "rechaza nombre duplicado case-insensitive" do
    Proveedor.create!(nombre: "Test Walmart", tipo: "comercio")
    dup = Proveedor.new(nombre: "TEST WALMART", tipo: "comercio")
    assert_not dup.valid?
  end

  test "rechaza tipo inválido" do
    p = Proveedor.new(nombre: "Test", tipo: "otra_cosa")
    assert_not p.valid?
  end

  test "codigo se normaliza a mayúsculas sin espacios" do
    p = Proveedor.create!(nombre: "Test", codigo: "abc 123", tipo: "comercio")
    assert_equal "ABC123", p.codigo
  end

  test "scope activos excluye inactivos" do
    activo   = Proveedor.create!(nombre: "Activo Test", tipo: "comercio", activo: true)
    inactivo = Proveedor.create!(nombre: "Inactivo Test", tipo: "comercio", activo: false)
    assert_includes Proveedor.activos, activo
    assert_not_includes Proveedor.activos, inactivo
  end

  test "scope buscar matchea nombre o codigo (ILIKE)" do
    nuevo = Proveedor.create!(nombre: "Buscable Único Xyz", tipo: "comercio")
    assert_includes Proveedor.buscar("buscable"), nuevo
    assert_includes Proveedor.buscar(nuevo.codigo.downcase), nuevo
  end

  test "entrega_personal? refleja el tipo" do
    p = Proveedor.new(tipo: "entrega_personal")
    assert p.entrega_personal?
    p.tipo = "comercio"
    assert_not p.entrega_personal?
  end

  test "generar_codigo_desde ignora caracteres no alfabéticos" do
    Proveedor.create!(nombre: "1A 2B 3C Test", tipo: "comercio") # toma "ABC" sólo letras
    candidato = Proveedor.generar_codigo_desde("1A 2B 3C Test 2")
    assert_match(/\AABC\d*\z/, candidato)
  end
end
