class PreAlertaMailer < ApplicationMailer
  def paquete_recibido(cliente, paquete)
    @cliente = cliente
    @paquete = paquete
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
