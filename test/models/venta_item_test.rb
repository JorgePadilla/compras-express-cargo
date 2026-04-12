require "test_helper"

class VentaItemTest < ActiveSupport::TestCase
  test "requires concepto" do
    item = VentaItem.new(venta: ventas(:pendiente_juan))
    assert_not item.valid?
    assert item.errors[:concepto].any?
  end

  test "calculates subtotal from peso * precio on save" do
    v = ventas(:pendiente_juan)
    item = v.venta_items.build(concepto: "Calc", peso_cobrar: 2, precio_libra: 10)
    item.valid?
    assert_equal "20.0".to_d, item.subtotal.to_d
  end

  test "belongs to venta" do
    item = venta_items(:pendiente_juan_item1)
    assert_equal ventas(:pendiente_juan), item.venta
  end
end
