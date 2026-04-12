class NotaCreditoMailer < ApplicationMailer
  def emitida(nota_credito)
    @nc      = nota_credito
    @venta   = nota_credito.venta
    @cliente = nota_credito.cliente
    @empresa = Empresa.instance
    return unless @cliente.email.present? && @cliente.notificar_facturas?

    attachments["nota-credito-#{@nc.numero}.pdf"] = NotaCreditoPdf.new(@nc).render
    mail to: @cliente.email,
         subject: "Nota de Credito #{@nc.numero} - #{@empresa.nombre}"
  end
end
