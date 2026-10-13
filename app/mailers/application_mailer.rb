class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "no-reply@comprasexpresscargo.com")
  layout "mailer"

  # PR-C31.10 · Cada correo que sale queda anotado en `correos_enviados`.
  #
  # Yusef, 2026-10-12, para SAC (`C31-20`): *"todos los correos enviados, **lo
  # que falló**"*. Va acá y no en cada mailer para que un mailer nuevo quede
  # anotado sin que nadie se acuerde.
  #
  # El fallo se ve solo porque producción tiene `raise_delivery_errors = true`:
  # con `false`, la gema `mail` se traga la excepción del SMTP y este callback
  # nunca se entera. Si alguien lo apaga, los fallidos desaparecen de la vista.
  #
  # Con `deliver_later`, cada reintento del job es un intento más y deja su fila.
  around_deliver :anotar_en_la_bitacora

  private

  def anotar_en_la_bitacora
    # Los mailers que no tienen a quién mandarle hacen `return` antes de `mail`:
    # el mensaje es un `NullMail` y el callback corre igual. No salió nada, no
    # se anota nada.
    anotar = @_mail_was_called && message.perform_deliveries && Array(message.to).any?
    return yield unless anotar

    begin
      yield
    rescue StandardError => e
      registrar_correo("fallido", "#{e.class}: #{e.message}")
      raise
    end

    registrar_correo(*estado_de_la_entrega)
  end

  # Sin `SMTP_ADDRESS`, producción cae a `:test` (ver `production.rb`) y el
  # correo no sale a ningún lado aunque no haya excepción. Para el cliente eso
  # es un correo que no le llegó, y así se anota.
  def estado_de_la_entrega
    if Rails.env.production? && self.class.delivery_method == :test
      [ "fallido", "SMTP sin configurar (SMTP_ADDRESS): el correo no salió del servidor" ]
    else
      [ "enviado", nil ]
    end
  end

  # Anotar nunca rompe el correo: si la bitácora falla, el correo ya salió (o ya
  # falló con su propia excepción) y eso es lo que importa.
  def registrar_correo(estado, error)
    CorreoEnviado.create!(
      cliente: cliente_del_correo,
      mailer: self.class.name,
      accion: action_name.to_s,
      para: Array(message.to).join(", ").truncate(255),
      asunto: message.subject.to_s.truncate(255),
      estado: estado,
      error: error&.truncate(2000),
      enviado_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("[correos_enviados] no se pudo anotar #{self.class.name}##{action_name}: #{e.class}: #{e.message}")
  end

  # De quién es el correo. Casi todos los mailers dejan `@cliente` (o `@cuenta`,
  # la clave del portal), y el callback corre en esa misma instancia: no hace
  # falta que cada mailer lo anuncie. Pero cuenta solo si el correo **le llegó a
  # él**: la cotización aceptada lleva `@cliente` y va a la empresa.
  #
  # Si no, se lo busca por la dirección: la de acceso o una de sus de aviso.
  def cliente_del_correo
    destinos = Array(message.to).map { |d| d.to_s.strip.downcase }
    propio = [ @cliente, @cuenta ].find { |c| c.is_a?(Cliente) }
    return propio if propio && (direcciones_de(propio) & destinos).any?

    Cliente.where("LOWER(email) IN (?)", destinos).first ||
      ClienteCorreo.where(correo: destinos).first&.cliente
  end

  def direcciones_de(cliente)
    [ cliente.email, *cliente.cliente_correos.map(&:correo) ].compact.map { |d| d.strip.downcase }
  end
end
