require "test_helper"

class ReciboPdfTest < ActiveSupport::TestCase
  test "renders PDF bytes" do
    recibo = recibos(:recibo_maria)
    output = ReciboPdf.new(recibo).render
    assert_kind_of String, output
    assert output.bytesize > 0
    assert output.start_with?("%PDF-")
  end
end
