require "test_helper"

class ClienteSessionTest < ActiveSupport::TestCase
  test "belongs to cliente" do
    cs = cliente_sessions(:juan_session)
    assert_equal clientes(:juan), cs.cliente
  end

  test "requires cliente" do
    cs = ClienteSession.new
    assert_not cs.valid?
  end
end
