require "test_helper"

# C33-05 · Los tres correos del casillero, con las mismas direcciones que
# «Mis Direcciones».
class CasilleroMailerTest < ActionMailer::TestCase
  setup do
    @cliente = clientes(:juan)
  end

  test "bienvenida: su codigo y sus direcciones, en html y en texto" do
    email = CasilleroMailer.bienvenida(@cliente)

    assert_emails(1) { email.deliver_now }
    assert_equal [ @cliente.email ], email.to
    assert_match @cliente.codigo, email.subject
    [ email.html_part, email.text_part ].each do |parte|
      cuerpo = parte.body.to_s
      assert_match "8109 NW 60TH STREET", cuerpo
      assert_match "REEMPAQUE AEREO", cuerpo
      assert_match "#{@cliente.codigo} #{@cliente.nombre_completo.upcase}", cuerpo
      assert_match "/cuenta/direcciones", cuerpo
    end
  end

  test "informacion actualizada: la misma plantilla con otro asunto" do
    email = CasilleroMailer.informacion_actualizada(@cliente)

    assert_equal [ @cliente.email ], email.to
    assert_match "direcciones de su casillero", email.subject
    assert_match "MARITIMO CKM", email.text_part.body.to_s
  end

  test "informacion general: sin cliente, el nombre es la instruccion y va el link para registrarse" do
    email = CasilleroMailer.informacion_general("alguien@example.com", nombre: "María")

    assert_emails(1) { email.deliver_now }
    assert_equal [ "alguien@example.com" ], email.to
    texto = email.text_part.body.to_s
    assert_match "Hola María", texto
    assert_match DireccionesDelCasillero::SIN_CLIENTE, texto
    assert_match "/registro/new", texto
    assert_nil CorreoEnviado.last.cliente, "en la bitácora queda sin cliente"
  end

  test "sin correo no sale" do
    @cliente.email = nil

    assert_nil CasilleroMailer.bienvenida(@cliente).to
    assert_nil CasilleroMailer.informacion_actualizada(@cliente).to
  end
end
