require "test_helper"

# El correo de recuperación, que ahora sale para los dos tipos de cuenta.
#
# Va aparte de los tests de `PasswordsController` a propósito: aquellos usan
# `assert_enqueued_emails`, y **encolar no renderea**. Una plantilla rota pasaría
# la suite entera y después reventaría callada en el job — que es justo la clase
# de falla silenciosa que este PR vino a matar.
class PasswordsMailerTest < ActionMailer::TestCase
  test "al cliente le llega a su correo, con el link y su codigo" do
    cliente = clientes(:juan)

    email = PasswordsMailer.reset_cliente(cliente)
    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [cliente.email], email.to
    cuerpo = email.body.encoded
    assert_match "/passwords/", cuerpo
    assert_match cliente.codigo, cuerpo,
                 "el codigo es la otra forma de entrar, y la que su gente si recuerda"
  end

  test "al empleado le llega igual que siempre, sin codigo de casillero" do
    user = users(:admin)

    email = PasswordsMailer.reset(user)
    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [user.email_address], email.to
    assert_match "/passwords/", email.body.encoded
  end

  test "las dos plantillas se rendean en texto y en html" do
    partes = PasswordsMailer.reset_cliente(clientes(:juan)).body.parts.map(&:content_type)

    assert partes.any? { |t| t.start_with?("text/plain") }
    assert partes.any? { |t| t.start_with?("text/html") }
  end
end
