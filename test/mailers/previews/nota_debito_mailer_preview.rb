class NotaDebitoMailerPreview < ActionMailer::Preview
  def emitida
    nd = NotaDebito.emitidas.first || NotaDebito.first
    NotaDebitoMailer.emitida(nd)
  end
end
