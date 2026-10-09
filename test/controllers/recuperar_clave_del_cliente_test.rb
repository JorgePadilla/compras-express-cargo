require "test_helper"

# "Olvidé mi contraseña", ahora también para el cliente.
#
# El link estaba en el login desde siempre, pero `PasswordsController` buscaba
# solo en `User`: un cliente lo apretaba, le contestaba *"instrucciones enviadas
# (si existe una cuenta con ese correo)"* y no pasaba nada. Falla en silencio, que
# es la peor clase de falla — el cliente cree que el correo viene en camino.
class RecuperarClaveDelClienteTest < ActionDispatch::IntegrationTest
  setup do
    @cliente = clientes(:juan)
    @cliente.update!(password: "Cliente123!", acceso_habilitado: true, activo: true)
  end

  # ── Pedirla ─────────────────────────────────────────────────────────────

  test "pedirla con el correo le manda el mail" do
    assert_enqueued_emails 1 do
      post passwords_path, params: { email_address: @cliente.email }
    end
  end

  # Yusef: *"es que yo no tengo correo"* / *"es que mi correo está lleno"*. El
  # que entra con su código tiene que poder pedirla con su código.
  test "y con el codigo de casillero tambien" do
    assert_enqueued_emails 1 do
      post passwords_path, params: { email_address: @cliente.codigo }
    end
  end

  test "el empleado sigue funcionando igual" do
    assert_enqueued_emails 1 do
      post passwords_path, params: { email_address: users(:admin).email_address }
    end
  end

  test "a un cliente con el acceso cortado no se le manda nada" do
    @cliente.update!(acceso_habilitado: false)

    assert_no_enqueued_emails do
      post passwords_path, params: { email_address: @cliente.codigo }
    end
  end

  # Encontrarlo por código pero no tener a dónde escribirle no puede reventar:
  # es exactamente el caso del cliente sin correo, que es el que Yusef describe.
  test "un cliente sin correo no revienta, solo no recibe nada" do
    @cliente.update_columns(email: nil)

    assert_no_enqueued_emails do
      post passwords_path, params: { email_address: @cliente.codigo }
    end
    assert_redirected_to new_session_path
  end

  test "una cuenta que no existe contesta lo mismo, sin delatar nada" do
    assert_no_enqueued_emails do
      post passwords_path, params: { email_address: "no-existe@example.com" }
    end
    assert_redirected_to new_session_path
  end

  # ── Usarla ──────────────────────────────────────────────────────────────

  test "el link del cliente le deja poner clave nueva" do
    token = @cliente.password_reset_token

    put password_path(token), params: {
      password: "Nueva12345", password_confirmation: "Nueva12345"
    }
    assert_redirected_to new_session_path

    assert_equal @cliente, Cliente.autenticar(@cliente.codigo, "Nueva12345")
    assert_nil Cliente.autenticar(@cliente.codigo, "Cliente123!")
  end

  test "y le deja la huella en la bitacora" do
    token = @cliente.password_reset_token
    @cliente.update_columns(clave_actualizada_at: nil)

    put password_path(token), params: {
      password: "Nueva12345", password_confirmation: "Nueva12345"
    }

    assert @cliente.reload.clave_actualizada_at.present?
  end

  test "el link del empleado sigue andando" do
    user = users(:admin)
    token = user.password_reset_token

    put password_path(token), params: {
      password: "otraclave123", password_confirmation: "otraclave123"
    }
    assert_redirected_to new_session_path
    assert User.authenticate_by(email_address: user.email_address, password: "otraclave123")
  end

  test "un token inventado no sirve para nada" do
    put password_path("basura"), params: {
      password: "Nueva12345", password_confirmation: "Nueva12345"
    }
    assert_redirected_to new_password_path
    assert_equal @cliente, Cliente.autenticar(@cliente.codigo, "Cliente123!")
  end

  test "clave corta rebota y no cambia nada" do
    token = @cliente.password_reset_token

    put password_path(token), params: { password: "corta", password_confirmation: "corta" }

    assert_equal @cliente, Cliente.autenticar(@cliente.codigo, "Cliente123!")
  end

  # ── La pantalla ─────────────────────────────────────────────────────────

  test "la pantalla pide correo o codigo, no solo correo" do
    get new_password_path

    assert_match "codigo de casillero", response.body
    assert_no_match(/type="email"[^>]*name="email_address"/, response.body)
  end
end
