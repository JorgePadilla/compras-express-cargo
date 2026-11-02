class ResumenDeEnviosMailerPreview < ActionMailer::Preview
  # C33-03 · El resumen de las 6 pm, con los paquetes que tengan fecha de
  # enviado del primer cliente que encuentre.
  def del_dia
    paquetes = Paquete.where.not(fecha_enviado: nil).includes(:tipo_envio).limit(20).to_a
    cliente = paquetes.first&.cliente || Cliente.first
    ResumenDeEnviosMailer.del_dia(cliente, paquetes.select { |p| p.cliente_id == cliente.id })
  end
end
