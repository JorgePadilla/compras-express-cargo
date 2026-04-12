require "test_helper"

class NotaDebitoMailerTest < ActionMailer::TestCase
  test "emitida sends with PDF attachment" do
    nd = notas_debito(:nd_emitida)
    email = NotaDebitoMailer.emitida(nd)
    assert_emails 1 do
      email.deliver_now
    end
    assert_equal [nd.cliente.email], email.to
    assert_match nd.numero, email.subject
    assert_equal 1, email.attachments.size
    assert_match(/ND-.*\.pdf/, email.attachments.first.filename)
  end

  test "emitida skips when no email" do
    nd = notas_debito(:nd_emitida)
    nd.cliente.email = nil
    email = NotaDebitoMailer.emitida(nd)
    assert_nil email.to
  end

  test "emitida skips when notificar_facturas false" do
    nd = notas_debito(:nd_emitida)
    nd.cliente.update_column(:notificar_facturas, false)
    email = NotaDebitoMailer.emitida(nd)
    assert_nil email.to
  end
end
