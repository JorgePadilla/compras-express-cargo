class ProformaMailer < ApplicationMailer
  def enviada(venta)
    @venta   = venta
    @cliente = venta.cliente
    @empresa = Empresa.instance
    return unless @cliente.email.present?

    attachments["proforma-#{@venta.numero}.pdf"] = VentaPdf.new(@venta).render
    mail to: @cliente.email,
         subject: "Proforma #{@venta.numero} - #{@empresa.nombre}"
  end
end
