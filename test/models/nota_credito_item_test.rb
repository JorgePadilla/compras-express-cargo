require "test_helper"

class NotaCreditoItemTest < ActiveSupport::TestCase
  test "validates concepto presence" do
    item = NotaCreditoItem.new(nota_credito: notas_credito(:nc_creada), subtotal: 10)
    assert_not item.valid?
    assert item.errors[:concepto].any?
  end

  test "validates subtotal presence" do
    item = NotaCreditoItem.new(nota_credito: notas_credito(:nc_creada), concepto: "Test")
    item.subtotal = nil
    assert_not item.valid?
  end

  test "calculate_subtotal from peso and precio" do
    item = NotaCreditoItem.new(
      nota_credito: notas_credito(:nc_creada),
      paquete: paquetes(:disponible_entrega_juan),
      concepto: "Test",
      peso_cobrar: 4,
      precio_libra: 2.50
    )
    item.valid?
    assert_equal 10.to_d, item.subtotal.to_d
  end
end
