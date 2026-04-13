class FacturaMailerPreview < ActionMailer::Preview
  def pendiente
    venta = Venta.first || OpenStruct.new
    FacturaMailer.pendiente(venta)
  end

  def pagada
    venta  = Venta.pagadas.first || Venta.first
    recibo = venta&.recibos&.first || Recibo.first
    FacturaMailer.pagada(venta, recibo)
  end
end
