require "test_helper"

# Una categoría agrupa clientes; no guarda precios.
#
# Yusef, 2026-08-12: *"la categoría de precio confunde con la tabla de servicios,
# y está en lempiras la de categoría y el Excel está en dólares"*. Las columnas
# de precio se fueron: rotulaban lempiras sobre números que estaban en dólares
# (la tabla no tenía `moneda`) y desde `PR-C7.06` ningún cálculo las leía.
class CategoriaPrecioTest < ActiveSupport::TestCase
  test "requires nombre" do
    cp = CategoriaPrecio.new
    assert_not cp.valid?
    assert_includes cp.errors[:nombre], "no puede estar en blanco"
  end

  test "rejects duplicate nombre case-insensitive" do
    CategoriaPrecio.create!(nombre: "Duplicada")
    assert_not CategoriaPrecio.new(nombre: "duplicada").valid?
  end

  test "to_s returns nombre" do
    assert_equal "Regular", categoria_precios(:regular).to_s
  end

  # La guarda del arreglo: si alguien vuelve a agregarle columnas de precio a
  # esta tabla, volvemos a tener dos fuentes de verdad y una de las dos sin
  # moneda declarada.
  test "la categoria no tiene columnas de precio" do
    columnas = CategoriaPrecio.column_names

    %w[precio_libra_aereo precio_libra_maritimo precio_volumen].each do |c|
      refute_includes columnas, c,
                      "volvió una columna de precio a `categoria_precios`; el precio vive en `tarifas`, que sí tiene moneda"
    end
  end

  test "tarifas_vigentes muestra lo que la categoria cobra" do
    categoria = categoria_precios(:regular)
    tarifa = Tarifa.create!(tipo_envio: tipo_envios(:cer), categoria_precio: categoria,
                            desde_libras: 0, precio_libra: 3.50, moneda: "USD", activo: true)

    assert_includes categoria.tarifas_vigentes, tarifa
  end

  test "sin tarifas propias la lista sale vacia, que es lo que la pantalla informa" do
    assert_empty categoria_precios(:vip).tarifas_vigentes,
                 "VIP no tiene tarifas: sus clientes pagan precio de lista"
  end
end
