class PreAlertaMailerPreview < ActionMailer::Preview
  # C33-02 · El de creación, con la copia a SAC.
  def confirmacion
    PreAlertaMailer.confirmacion(PreAlerta.joins(:cliente).first, copia_a_sac: true)
  end
end
