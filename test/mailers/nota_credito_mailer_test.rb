require "test_helper"

class NotaCreditoMailerTest < ActionMailer::TestCase
  test "emitida sends with PDF attachment" do
    nc = notas_credito(:nc_emitida)
    email = NotaCreditoMailer.emitida(nc)
    assert_emails 1 do
      email.deliver_now
    end
    assert_equal [nc.cliente.email], email.to
    assert_match nc.numero, email.subject
    assert_equal 1, email.attachments.size
    assert_match(/NC-.*\.pdf/, email.attachments.first.filename)
  end

  test "emitida skips when no email" do
    nc = notas_credito(:nc_emitida)
    nc.cliente.email = nil
    email = NotaCreditoMailer.emitida(nc)
    assert_nil email.to
  end

  test "emitida skips when notificar_facturas false" do
    nc = notas_credito(:nc_emitida)
    nc.cliente.update_column(:notificar_facturas, false)
    email = NotaCreditoMailer.emitida(nc)
    assert_nil email.to
  end
end
