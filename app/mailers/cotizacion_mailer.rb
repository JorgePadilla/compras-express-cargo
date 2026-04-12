class CotizacionMailer < ApplicationMailer
  def enviada(cotizacion)
    @cotizacion = cotizacion
    @cliente    = cotizacion.cliente
    @empresa    = Empresa.instance
    return unless @cliente.email.present?

    attachments["cotizacion-#{@cotizacion.numero}.pdf"] = CotizacionPdf.new(@cotizacion).render
    mail to: @cliente.email,
         subject: "Cotizacion #{@cotizacion.numero} - #{@empresa.nombre}"
  end

  def aceptada(cotizacion)
    @cotizacion = cotizacion
    @cliente    = cotizacion.cliente
    @empresa    = Empresa.instance
    return unless @empresa.email_contacto.present?

    mail to: @empresa.email_contacto,
         subject: "Cotizacion #{@cotizacion.numero} aceptada por #{@cliente.nombre_completo}"
  end
end
