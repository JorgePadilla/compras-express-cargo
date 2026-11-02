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
    # C31-11 · La «posible fecha de entrega» en días hábiles, que reemplaza el
    # *"será incluido en el próximo envío disponible"*. La fija
    # `notificar_recibido` antes de encolar; si el servicio no tiene días
    # cargados no hay fecha, y el correo dice lo de antes.
    @fecha_entrega = paquete.fecha_posible_entrega && FechaDeEntrega.texto(paquete.fecha_posible_entrega)
    return unless @cliente.email.present?

    mail to: @cliente.email, subject: "Paquete #{paquete.guia} recibido en #{@sucursal}"
  end

  # C33-02 · Con `copia_a_sac`, la copia va a la casilla de SAC. Si el
  # cliente no tiene correo, sale igual, solo a SAC: es quien la supervisa.
  def confirmacion(pre_alerta, copia_a_sac: false)
    @pre_alerta = pre_alerta
    @cliente = pre_alerta.cliente
    copia = (self.class.correo_de_sac if copia_a_sac)
    para = @cliente.email.presence || copia
    return if para.blank?

    mail to: para, cc: (copia unless para == copia),
         subject: "Pre-Alerta #{pre_alerta.numero_documento} confirmada"
  end

  # La casilla es la que Yusef escribió en la planilla (C33-01). Si cambia
  # (`RP-109`), se cambia en `Configuracion`, no acá: el mismo patrón que
  # `ManifiestoMailer#destino`.
  CORREO_DE_SAC = "sac@comprasexpresshn.com".freeze

  def self.correo_de_sac
    Configuracion.get("correo_copia_pre_alertas").presence || CORREO_DE_SAC
  end
end
