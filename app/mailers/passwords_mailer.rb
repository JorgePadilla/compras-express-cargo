class PasswordsMailer < ApplicationMailer
  def reset(user)
    @cuenta = user
    mail subject: "Recupera tu contrasena", to: user.email_address
  end

  # PR-C7.37: la misma plantilla para el cliente. Lo único que cambia es a dónde
  # va —`Cliente` guarda el correo en `email`, no en `email_address`— y que se le
  # recuerda el código, que es la otra forma de entrar y la que su gente sí
  # recuerda.
  def reset_cliente(cliente)
    @cuenta = cliente
    @codigo = cliente.codigo
    mail subject: "Recupera tu contrasena", to: cliente.email, template_name: "reset"
  end
end
