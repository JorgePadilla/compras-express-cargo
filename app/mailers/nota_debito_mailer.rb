class NotaDebitoMailer < ApplicationMailer
  def emitida(nota_debito)
    @nd      = nota_debito
    @venta   = nota_debito.venta
    @cliente = nota_debito.cliente
    @empresa = Empresa.instance
    return unless @cliente.email.present? && @cliente.notificar_facturas?

    attachments["nota-debito-#{@nd.numero}.pdf"] = NotaDebitoPdf.new(@nd).render
    mail to: @cliente.email,
         subject: "Nota de Debito #{@nd.numero} - #{@empresa.nombre}"
  end
end
