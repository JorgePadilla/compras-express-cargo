class CasilleroMailerPreview < ActionMailer::Preview
  # C33-05 · Los tres correos del casillero.
  def bienvenida
    CasilleroMailer.bienvenida(Cliente.where.not(email: nil).first)
  end

  def informacion_actualizada
    CasilleroMailer.informacion_actualizada(Cliente.where.not(email: nil).first)
  end

  def informacion_general
    CasilleroMailer.informacion_general("alguien@example.com", nombre: "María")
  end
end
