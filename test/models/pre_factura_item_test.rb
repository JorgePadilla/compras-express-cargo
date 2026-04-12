require "test_helper"

class PreFacturaItemTest < ActiveSupport::TestCase
  test "requires concepto" do
    item = PreFacturaItem.new(pre_factura: pre_facturas(:borrador_juan))
    assert_not item.valid?
    assert item.errors[:concepto].any?
  end

  test "calculates subtotal from peso * precio on save" do
    pf = pre_facturas(:borrador_juan)
    item = pf.pre_factura_items.build(concepto: "Calc", peso_cobrar: 4, precio_libra: 3.5)
    item.valid?
    assert_equal "14.0".to_d, item.subtotal.to_d
  end

  test "does not recalculate when peso or precio missing" do
    item = PreFacturaItem.new(pre_factura: pre_facturas(:borrador_juan), concepto: "X", subtotal: 99)
    item.valid?
    assert_equal 99.to_d, item.subtotal.to_d
  end

  test "belongs to pre_factura" do
    item = pre_factura_items(:borrador_juan_item1)
    assert_equal pre_facturas(:borrador_juan), item.pre_factura
  end

  test "paquete is optional" do
    item = PreFacturaItem.new(pre_factura: pre_facturas(:borrador_juan), concepto: "Ajuste", subtotal: 10)
    assert item.valid?
  end
end
