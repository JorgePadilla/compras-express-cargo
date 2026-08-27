class PreAlertaMailer < ApplicationMailer
  # C18-06: lleva `notas_al_cliente` cuando existe — es el canal documentado
  # desde abril (*"viaja en el correo de notificación al cliente cuando llega
  # la carga a Miami"*) y nunca había viajado.
  def paquete_recibido(cliente, paquete)
    @cliente = cliente
    @paquete = paquete
    @nota = paquete.notas_al_cliente.to_s.strip.presence
    return unless @cliente.email.present?

    mail to: @cliente.email, subject: "Paquete #{paquete.guia} recibido en Miami"
  end

  def confirmacion(pre_alerta)
    @pre_alerta = pre_alerta
    @cliente = pre_alerta.cliente
    return unless @cliente.email.present?

    mail to: @cliente.email, subject: "Pre-Alerta #{pre_alerta.numero_documento} confirmada"
  end
end
