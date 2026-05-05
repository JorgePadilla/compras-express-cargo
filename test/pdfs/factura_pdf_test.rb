require "test_helper"

class FacturaPdfTest < ActiveSupport::TestCase
  test "renders PDF bytes" do
    venta = facturas(:pendiente_juan)
    pdf = FacturaPdf.new(venta)
    output = pdf.render
    assert_kind_of String, output
    assert output.bytesize > 0
    assert output.start_with?("%PDF-")
  end

  test "renders PDF for pagada venta" do
    venta = facturas(:pagada_maria)
    output = FacturaPdf.new(venta).render
    assert output.start_with?("%PDF-")
  end
end
