require "test_helper"

class NotaDebitoItemTest < ActiveSupport::TestCase
  test "validates concepto presence" do
    item = NotaDebitoItem.new(nota_debito: notas_debito(:nd_creada), subtotal: 10)
    assert_not item.valid?
    assert item.errors[:concepto].any?
  end

  test "validates subtotal presence" do
    item = NotaDebitoItem.new(nota_debito: notas_debito(:nd_creada), concepto: "Test")
    item.subtotal = nil
    assert_not item.valid?
  end

  test "calculate_subtotal from peso and precio" do
    item = NotaDebitoItem.new(
      nota_debito: notas_debito(:nd_creada),
      paquete: paquetes(:disponible_entrega_juan),
      concepto: "Test",
      peso_cobrar: 5,
      precio_libra: 3.50
    )
    item.valid?
    assert_equal 17.50.to_d, item.subtotal.to_d
  end
end
