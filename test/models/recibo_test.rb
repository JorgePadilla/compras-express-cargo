require "test_helper"

class ReciboTest < ActiveSupport::TestCase
  test "auto-generates numero" do
    recibo = Recibo.create!(
      venta: ventas(:pagada_maria),
      pago: pagos(:pago_maria),
      cliente: clientes(:maria),
      monto: 5.00,
      forma_pago: "efectivo"
    )
    assert_match /\ARE-\d{6}\z/, recibo.numero
  end

  test "requires unique numero" do
    dup = Recibo.new(
      numero: "RE-000001",
      venta: ventas(:pagada_maria),
      pago: pagos(:pago_maria),
      cliente: clientes(:maria),
      monto: 5.00
    )
    assert_not dup.valid?
  end

  test "belongs to venta, pago and cliente" do
    r = recibos(:recibo_maria)
    assert_equal ventas(:pagada_maria), r.venta
    assert_equal pagos(:pago_maria), r.pago
    assert_equal clientes(:maria), r.cliente
  end
end
