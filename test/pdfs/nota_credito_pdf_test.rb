require "test_helper"

class NotaCreditoPdfTest < ActiveSupport::TestCase
  test "renders PDF bytes" do
    nc = notas_credito(:nc_emitida)
    output = NotaCreditoPdf.new(nc).render
    assert_kind_of String, output
    assert output.bytesize > 0
    assert output.start_with?("%PDF-")
  end

  test "renders PDF for creada nota credito" do
    nc = notas_credito(:nc_creada)
    output = NotaCreditoPdf.new(nc).render
    assert output.start_with?("%PDF-")
  end
end
