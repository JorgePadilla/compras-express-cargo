require "test_helper"

class NotaDebitoPdfTest < ActiveSupport::TestCase
  test "renders PDF bytes" do
    nd = notas_debito(:nd_emitida)
    output = NotaDebitoPdf.new(nd).render
    assert_kind_of String, output
    assert output.bytesize > 0
    assert output.start_with?("%PDF-")
  end

  test "renders PDF for creada nota debito" do
    nd = notas_debito(:nd_creada)
    output = NotaDebitoPdf.new(nd).render
    assert output.start_with?("%PDF-")
  end
end
