require "test_helper"

class EntregaPaqueteTest < ActiveSupport::TestCase
  test "valid with entrega and paquete" do
    ep = EntregaPaquete.new(entrega: entregas(:pendiente_juan), paquete: paquetes(:facturado_juan2))
    assert ep.valid?
  end

  test "validates uniqueness of paquete scoped to entrega" do
    ep = EntregaPaquete.new(entrega: entregas(:pendiente_juan), paquete: paquetes(:facturado_juan))
    assert_not ep.valid?
  end
end
