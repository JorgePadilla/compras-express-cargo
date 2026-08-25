require "test_helper"

# Ponerle y cambiarle la clave del portal a un cliente.
#
# Es la mitad que `PR-C7.33` dejó afuera, y sin ella el resto no servía de nada:
# `cliente_params` no permitía `:password` y `PasswordsController` era solo de
# `User`, así que **un cliente creado por el admin nacía sin clave y no podía
# entrar nunca**. Le salía "contraseña incorrecta" para siempre y el link de
# "olvidé mi contraseña" le contestaba en silencio.
#
# Yusef, 2026-08-19, señalando la ficha del cliente:
#
#   > "Ella tiene dos correos, yo no le puedo crear una cuenta aquí."
#   > "¿Cuál es la cuenta de acceso de él? Eso es todo. Y cambiarle la clave por
#   >  si se le olvidó."
class ClaveDelClienteTest < ActionDispatch::IntegrationTest
  setup do
    @cliente = clientes(:juan)
    admin = users(:admin)
    post session_url, params: { email_address: admin.email_address, password: "password123" }
  end

  # ── El agujero que esto tapa ────────────────────────────────────────────

  test "un cliente recien creado por el admin no tiene clave y no entra" do
    post clientes_path, params: { cliente: {
      nombre: "Ana Maria", apellido: "Reyes Pineda", email: "ana.reyes@example.com"
    } }

    nuevo = Cliente.find_by(email: "ana.reyes@example.com")
    assert nuevo, "el cliente se tiene que haber creado"
    assert_not nuevo.tiene_clave?, "el alta no le pone clave, y por eso hace falta ponersela"
    assert nuevo.acceso_habilitado?, "el acceso viene habilitado, pero sin clave no alcanza"
    assert_nil Cliente.autenticar(nuevo.codigo, "loquesea")
  end

  # ── Ponersela desde la ficha ────────────────────────────────────────────

  test "el admin le pone la clave y con eso el cliente entra" do
    @cliente.update_columns(password_digest: nil, clave_actualizada_at: nil)

    patch clave_cliente_path(@cliente), params: { cliente: {
      password: "Nueva12345", password_confirmation: "Nueva12345"
    } }
    assert_redirected_to cliente_path(@cliente)

    assert @cliente.reload.tiene_clave?
    assert_equal @cliente, Cliente.autenticar(@cliente.codigo, "Nueva12345")
    assert_equal @cliente, Cliente.autenticar(@cliente.email, "Nueva12345")
  end

  test "cambiarsela invalida la anterior" do
    @cliente.update!(password: "Cliente123!")

    patch clave_cliente_path(@cliente), params: { cliente: {
      password: "Otra123456", password_confirmation: "Otra123456"
    } }

    assert_nil Cliente.autenticar(@cliente.codigo, "Cliente123!")
    assert_equal @cliente, Cliente.autenticar(@cliente.codigo, "Otra123456")
  end

  test "queda registrado cuando se la tocaron" do
    @cliente.update_columns(clave_actualizada_at: nil)

    freeze_time do
      patch clave_cliente_path(@cliente), params: { cliente: {
        password: "Nueva12345", password_confirmation: "Nueva12345"
      } }
      assert_equal Time.current.to_i, @cliente.reload.clave_actualizada_at.to_i
    end
  end

  # `password_digest` está en el `skip` de paper_trail, así que sin la columna de
  # fecha cambiar la clave de un cliente no dejaba ninguna huella.
  test "y la bitacora lo ve" do
    @cliente.update_columns(clave_actualizada_at: nil)

    assert_difference -> { @cliente.versions.count }, 1 do
      patch clave_cliente_path(@cliente), params: { cliente: {
        password: "Nueva12345", password_confirmation: "Nueva12345"
      } }
    end
    assert_includes @cliente.versions.last.object_changes.to_s, "clave_actualizada_at"
  end

  # ── Lo que no se le deja hacer ──────────────────────────────────────────

  test "una clave corta no pasa" do
    @cliente.update_columns(password_digest: nil)

    patch clave_cliente_path(@cliente), params: { cliente: {
      password: "corta", password_confirmation: "corta"
    } }

    assert_not @cliente.reload.tiene_clave?
    assert_match(/8/, flash[:alert].to_s)
  end

  test "si no coinciden tampoco" do
    @cliente.update_columns(password_digest: nil)

    patch clave_cliente_path(@cliente), params: { cliente: {
      password: "Nueva12345", password_confirmation: "Distinta12345"
    } }

    assert_not @cliente.reload.tiene_clave?
    assert flash[:alert].present?
  end

  test "mandarla vacia no le borra la que tenia" do
    @cliente.update!(password: "Cliente123!")

    patch clave_cliente_path(@cliente), params: { cliente: { password: "" } }

    assert @cliente.reload.tiene_clave?
    assert_equal @cliente, Cliente.autenticar(@cliente.codigo, "Cliente123!")
  end

  # Es un endpoint de apoderarse de una cuenta: vale la pena que esté escrito
  # que un cliente logueado no llega ni a la ficha ni a la clave de otro.
  test "un cliente logueado no puede tocarle la clave a nadie" do
    delete session_path
    @cliente.update!(password: "Cliente123!")
    post session_path, params: { email_address: @cliente.codigo, password: "Cliente123!" }

    patch clave_cliente_path(@cliente), params: { cliente: {
      password: "Robada12345", password_confirmation: "Robada12345"
    } }

    assert_response :redirect
    assert_nil Cliente.autenticar(@cliente.codigo, "Robada12345")
    assert_equal @cliente, Cliente.autenticar(@cliente.codigo, "Cliente123!")
  end

  # ── La ficha ────────────────────────────────────────────────────────────
  #
  #   > "Yo me voy a clientes, a mi listado de clientes, y administro su usuario."

  test "la ficha dice cual es la cuenta de acceso y si puede entrar" do
    @cliente.update!(password: "Cliente123!", acceso_habilitado: true)
    get cliente_path(@cliente)

    assert_select "h2", text: "Acceso al portal"
    assert_match @cliente.email, response.body
    assert_match @cliente.codigo, response.body
  end

  test "la ficha avisa cuando el cliente no tiene clave" do
    @cliente.update_columns(password_digest: nil)
    get cliente_path(@cliente)

    assert_match "todavía no tiene clave", response.body
  end

  test "y cuando tiene el acceso cortado" do
    @cliente.update!(password: "Cliente123!", acceso_habilitado: false)
    get cliente_path(@cliente)

    assert_match "tiene el acceso cortado", response.body
  end
end
