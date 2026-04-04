class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "Recupera tu contrasena", to: user.email_address
  end
end
