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

  # C31-11 · El correo da la fecha en días hábiles en vez de *"será incluido en
  # el próximo envío disponible"*, que es lo que Yusef señaló del nuestro.
  test "paquete_recibido dice la posible fecha de entrega con el día" do
    paquete = paquetes(:recibido)
    paquete.fecha_posible_entrega = Time.zone.local(2026, 10, 24) # un sábado

    email = PreAlertaMailer.paquete_recibido(clientes(:juan), paquete)

    [ email.html_part.body.to_s, email.text_part.body.to_s ].each do |cuerpo|
      assert_includes cuerpo, "Posible fecha de entrega"
      assert_includes cuerpo, "sábado 24/10"
      assert_not_includes cuerpo, "proximo envio disponible"
    end
  end

  test "paquete_recibido sin fecha dice lo de antes" do
    paquete = paquetes(:recibido)
    paquete.fecha_posible_entrega = nil

    email = PreAlertaMailer.paquete_recibido(clientes(:juan), paquete)

    [ email.html_part.body.to_s, email.text_part.body.to_s ].each do |cuerpo|
      assert_includes cuerpo, "Sera incluido en el proximo envio disponible"
      assert_not_includes cuerpo, "Posible fecha de entrega"
    end
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
