class NotaCreditoMailerPreview < ActionMailer::Preview
  def emitida
    nc = NotaCredito.emitidas.first || NotaCredito.first
    NotaCreditoMailer.emitida(nc)
  end
end
