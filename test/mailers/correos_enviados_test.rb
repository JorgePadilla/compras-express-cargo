require "test_helper"

# PR-C31.10 · La bitácora de correos que `ApplicationMailer` escribe en cada
# entrega. Yusef (`C31-20`): *"todos los correos enviados, lo que falló"*.
class CorreosEnviadosTest < ActionMailer::TestCase
  # Una entrega que falla como falla un SMTP de verdad: con una excepción
  # adentro de `deliver!`.
  class EntregaQueFalla
    def initialize(_settings = {}); end

    def deliver!(_mail)
      raise Errno::ECONNREFUSED, "connect(2) for smtp.ejemplo.com port 587"
    end
  end
  ActionMailer::Base.add_delivery_method :que_falla, EntregaQueFalla

  test "un correo que sale deja su fila de enviado, con el cliente" do
    cliente = clientes(:juan)
    paquete = paquetes(:recibido)

    assert_difference -> { CorreoEnviado.count }, 1 do
      PreAlertaMailer.paquete_recibido(cliente, paquete).deliver_now
    end

    correo = CorreoEnviado.last
    assert_equal "enviado", correo.estado
    assert_equal cliente, correo.cliente
    assert_equal "PreAlertaMailer", correo.mailer
    assert_equal "paquete_recibido", correo.accion
    assert_equal cliente.email, correo.para
    assert_match paquete.guia, correo.asunto
    assert_nil correo.error
    assert_not_nil correo.enviado_at
  end

  test "el mailer que no tiene a quién mandarle no anota nada" do
    cliente = clientes(:juan)
    cliente.email = nil

    assert_no_difference -> { CorreoEnviado.count } do
      PreAlertaMailer.paquete_recibido(cliente, paquetes(:recibido)).deliver_now
    end
  end

  test "un correo que falla queda como fallido con su error, y la excepción sigue" do
    cliente = clientes(:juan)
    PreAlertaMailer.delivery_method = :que_falla

    assert_raises(Errno::ECONNREFUSED) do
      PreAlertaMailer.paquete_recibido(cliente, paquetes(:recibido)).deliver_now
    end

    correo = CorreoEnviado.last
    assert_equal "fallido", correo.estado
    assert_equal cliente, correo.cliente
    assert_match "ECONNREFUSED", correo.error
    assert_match "smtp.ejemplo.com", correo.error
  ensure
    PreAlertaMailer.delivery_method = ActionMailer::Base.delivery_method
  end

  # Producción sin `SMTP_ADDRESS` cae a `:test`: no hay excepción, pero el
  # correo no sale a ningún lado. Para el cliente es uno que no le llegó.
  test "en producción sin SMTP el correo se anota como fallido" do
    Rails.env = "production"
    PreAlertaMailer.paquete_recibido(clientes(:juan), paquetes(:recibido)).deliver_now

    correo = CorreoEnviado.last
    assert_equal "fallido", correo.estado
    assert_match "SMTP", correo.error
  ensure
    Rails.env = "test"
  end

  test "el correo a un usuario no se le cuelga a ningún cliente" do
    assert_difference -> { CorreoEnviado.count }, 1 do
      PasswordsMailer.reset(users(:admin)).deliver_now
    end

    correo = CorreoEnviado.last
    assert_nil correo.cliente
    assert_equal "PasswordsMailer", correo.mailer
    assert_equal "reset", correo.accion
  end

  # La cotización aceptada lleva `@cliente` pero va a la empresa: no es un
  # correo que el cliente recibió.
  test "un correo con @cliente que va a otra dirección no es del cliente" do
    Empresa.instance.update_columns(email_contacto: "ventas@cec.test")
    cotizacion = Cotizacion.first
    skip "sin cotizaciones en las fixtures" unless cotizacion

    CotizacionMailer.aceptada(cotizacion).deliver_now

    correo = CorreoEnviado.last
    assert_equal "ventas@cec.test", correo.para
    assert_nil correo.cliente
  end

  test "un correo de aviso encuentra al cliente por su dirección" do
    cliente = clientes(:juan)
    cliente.cliente_correos.create!(correo: "aviso.juan@example.com")

    mail = Class.new(ApplicationMailer) do
      def self.name = "AvisoDePruebaMailer"

      def aviso
        mail(to: "Aviso.Juan@example.com", subject: "Aviso", body: "hola")
      end
    end

    mail.aviso.deliver_now

    assert_equal cliente, CorreoEnviado.last.cliente
  end

  test "si anotar falla, el correo sale igual" do
    CorreoEnviado.define_singleton_method(:create!) { |*| raise ActiveRecord::StatementInvalid, "se cayó la base" }

    assert_emails 1 do
      PreAlertaMailer.paquete_recibido(clientes(:juan), paquetes(:recibido)).deliver_now
    end
  ensure
    CorreoEnviado.singleton_class.remove_method(:create!)
  end
end
