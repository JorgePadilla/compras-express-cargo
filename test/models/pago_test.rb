require "test_helper"

class PagoTest < ActiveSupport::TestCase
  test "requires positive monto" do
    pago = Pago.new(venta: ventas(:pendiente_juan), cliente: clientes(:juan), metodo_pago: "efectivo", monto: 0)
    assert_not pago.valid?
    assert pago.errors[:monto].any?
  end

  test "requires valid metodo_pago" do
    pago = Pago.new(venta: ventas(:pendiente_juan), cliente: clientes(:juan), monto: 10, metodo_pago: "bitcoin")
    assert_not pago.valid?
    assert pago.errors[:metodo_pago].any?
  end

  test "accepts efectivo, tarjeta and transferencia" do
    Pago::METODOS.each do |m|
      pago = Pago.new(venta: ventas(:pendiente_juan), cliente: clientes(:juan), monto: 10, metodo_pago: m)
      assert pago.valid?, "#{m} should be valid"
    end
  end

  test "belongs to venta and cliente" do
    pago = pagos(:pago_maria)
    assert_equal ventas(:pagada_maria), pago.venta
    assert_equal clientes(:maria), pago.cliente
  end
end
