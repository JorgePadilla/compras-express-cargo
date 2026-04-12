class FacturaMailer < ApplicationMailer
  def pendiente(venta)
    @venta   = venta
    @cliente = venta.cliente
    @empresa = Empresa.instance
    return unless @cliente.email.present? && @cliente.notificar_facturas?

    attachments["factura-#{@venta.numero}.pdf"] = VentaPdf.new(@venta).render
    mail to: @cliente.email,
         subject: "Factura #{@venta.numero} - #{@empresa.nombre}"
  end

  def pagada(venta, recibo)
    @venta   = venta
    @recibo  = recibo
    @cliente = venta.cliente
    @empresa = Empresa.instance
    return unless @cliente.email.present? && @cliente.notificar_facturas?

    attachments["recibo-#{@recibo.numero}.pdf"] = ReciboPdf.new(@recibo).render
    mail to: @cliente.email,
         subject: "Recibo #{@recibo.numero} - Pago recibido"
  end
end
