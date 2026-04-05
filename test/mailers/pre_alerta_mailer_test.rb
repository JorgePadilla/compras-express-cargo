require "test_helper"

class PreAlertaMailerTest < ActionMailer::TestCase
  test "paquete_recibido" do
    cliente = clientes(:juan)
    paquete = paquetes(:recibido)

    email = PreAlertaMailer.paquete_recibido(cliente, paquete)
    assert_emails 1 do
      email.deliver_now
    end
    assert_equal [cliente.email], email.to
    assert_match paquete.guia, email.subject
  end

  test "paquete_recibido skips when no email" do
    cliente = clientes(:juan)
    cliente.email = nil
    paquete = paquetes(:recibido)

    email = PreAlertaMailer.paquete_recibido(cliente, paquete)
    assert_nil email.to
  end

  test "confirmacion" do
    pre_alerta = pre_alertas(:activa)

    email = PreAlertaMailer.confirmacion(pre_alerta)
    assert_emails 1 do
      email.deliver_now
    end
    assert_equal [pre_alerta.cliente.email], email.to
    assert_match pre_alerta.numero_documento, email.subject
  end

  test "confirmacion skips when no email" do
    pre_alerta = pre_alertas(:activa)
    pre_alerta.cliente.email = nil

    email = PreAlertaMailer.confirmacion(pre_alerta)
    assert_nil email.to
  end
end
