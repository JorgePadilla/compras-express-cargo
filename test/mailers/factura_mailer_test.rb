require "test_helper"

class FacturaMailerTest < ActionMailer::TestCase
  setup do
    @venta = ventas(:pendiente_juan)
    @recibo = recibos(:recibo_maria) rescue nil
  end

  test "pendiente sends to cliente with PDF attachment" do
    email = FacturaMailer.pendiente(@venta)
    assert_emails 1 do
      email.deliver_now
    end
    assert_equal [@venta.cliente.email], email.to
    assert_match @venta.numero, email.subject
    assert_equal 1, email.attachments.size
    assert_match(/factura-.*\.pdf/, email.attachments.first.filename)
    assert_equal "application/pdf", email.attachments.first.content_type.split(";").first
  end

  test "pendiente skips when no email" do
    @venta.cliente.email = nil
    email = FacturaMailer.pendiente(@venta)
    assert_nil email.to
  end

  test "pendiente skips when notificar_facturas is false" do
    @venta.cliente.update_column(:notificar_facturas, false)
    email = FacturaMailer.pendiente(@venta)
    assert_nil email.to
  end

  test "pagada sends with recibo PDF attachment" do
    venta = ventas(:pagada_maria)
    recibo = recibos(:recibo_maria)
    email = FacturaMailer.pagada(venta, recibo)
    assert_emails 1 do
      email.deliver_now
    end
    assert_equal [venta.cliente.email], email.to
    assert_match recibo.numero, email.subject
    assert_equal 1, email.attachments.size
  end
end
