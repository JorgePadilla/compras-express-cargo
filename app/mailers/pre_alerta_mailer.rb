class PreAlertaMailer < ApplicationMailer
  # C18-06: lleva `notas_al_cliente` cuando existe — es el canal documentado
  # desde abril (*"viaja en el correo de notificación al cliente cuando llega
  # la carga a Miami"*) y nunca había viajado.
  def paquete_recibido(cliente, paquete)
    @cliente = cliente
    @paquete = paquete
    @nota = paquete.notas_al_cliente.to_s.strip.presence
    # Dónde se recibió, que ya no es siempre Miami (C18-02). Los viejos no
    # tienen sucursal de recepción: para ellos sigue siendo Miami.
    @sucursal = paquete.sucursal_recepcion&.nombre || "Miami"
    return unless @cliente.email.present?

    mail to: @cliente.email, subject: "Paquete #{paquete.guia} recibido en #{@sucursal}"
  end

  def confirmacion(pre_alerta)
    @pre_alerta = pre_alerta
    @cliente = pre_alerta.cliente
    return unless @cliente.email.present?

    mail to: @cliente.email, subject: "Pre-Alerta #{pre_alerta.numero_documento} confirmada"
  end
end
