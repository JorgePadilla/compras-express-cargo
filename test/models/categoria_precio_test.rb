require "test_helper"

class CategoriaPrecioTest < ActiveSupport::TestCase
  test "requires nombre" do
    cp = CategoriaPrecio.new
    assert_not cp.valid?
    assert_includes cp.errors[:nombre], "no puede estar en blanco"
  end

  test "rejects duplicate nombre case-insensitive" do
    CategoriaPrecio.create!(nombre: "Duplicada", precio_libra_aereo: 1, precio_libra_maritimo: 1)
    dup = CategoriaPrecio.new(nombre: "duplicada", precio_libra_aereo: 1, precio_libra_maritimo: 1)
    assert_not dup.valid?
  end

  test "precio_para returns aereo rate for aereo modalidad" do
    cp = categoria_precios(:regular)
    assert_equal cp.precio_libra_aereo, cp.precio_para(tipo_envios(:aereo))
  end

  test "precio_para returns maritimo rate for maritimo modalidad" do
    cp = categoria_precios(:regular)
    assert_equal cp.precio_libra_maritimo, cp.precio_para(tipo_envios(:maritimo))
  end

  test "precio_para returns nil for nil tipo_envio" do
    assert_nil categoria_precios(:regular).precio_para(nil)
  end

  test "to_s returns nombre" do
    assert_equal "Regular", categoria_precios(:regular).to_s
  end
end
