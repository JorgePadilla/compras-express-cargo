require "test_helper"

class VentaPdfTest < ActiveSupport::TestCase
  test "renders PDF bytes" do
    venta = ventas(:pendiente_juan)
    pdf = VentaPdf.new(venta)
    output = pdf.render
    assert_kind_of String, output
    assert output.bytesize > 0
    assert output.start_with?("%PDF-")
  end

  test "renders PDF for pagada venta" do
    venta = ventas(:pagada_maria)
    output = VentaPdf.new(venta).render
    assert output.start_with?("%PDF-")
  end
end
