require "test_helper"

# El acceso del cliente al portal, administrable desde su ficha.
#
# Yusef, 2026-08-19: *"falta el sistema de usuario… lo del acceso de ellos"*. El
# cliente ya podía entrar —`Cliente` tiene `email` y `password_digest` desde
# siempre— pero no había dónde administrarlo: *"¿cuál es la cuenta de acceso de
# él? Y cambiarle la clave por si se le olvidó"*.
class AccesoDelClienteTest < ActionDispatch::IntegrationTest
  setup do
    @cliente = clientes(:juan)
    @cliente.update!(password: "Cliente123!", acceso_habilitado: true, activo: true)
  end

  # ── Entrar ──────────────────────────────────────────────────────────────
  #
  #   > "Es que mi correo está lleno." · "Es que yo no tengo correo."
  #   > "Yo quería que los clientes tengan acceso por su código de cliente."

  test "entra con su codigo de casillero" do
    post session_url, params: { email_address: @cliente.codigo, password: "Cliente123!" }

    assert_redirected_to cuenta_root_path
  end

  test "y con su correo, como siempre" do
    post session_url, params: { email_address: @cliente.email, password: "Cliente123!" }

    assert_redirected_to cuenta_root_path
  end

  test "el correo entra sin importar mayusculas" do
    post session_url, params: { email_address: @cliente.email.upcase, password: "Cliente123!" }

    assert_redirected_to cuenta_root_path
  end

  test "con la clave equivocada no entra por ninguno de los dos" do
    post session_url, params: { email_address: @cliente.codigo, password: "otra" }
    assert_redirected_to new_session_path

    post session_url, params: { email_address: @cliente.email, password: "otra" }
    assert_redirected_to new_session_path
  end

  # ── Cortarle el acceso ──────────────────────────────────────────────────

  test "sin acceso habilitado no entra, aunque siga siendo cliente" do
    @cliente.update!(acceso_habilitado: false)

    post session_url, params: { email_address: @cliente.codigo, password: "Cliente123!" }

    assert_redirected_to new_session_path
    assert @cliente.reload.activo?, "cortarle el acceso no lo da de baja"
  end

  test "y un cliente dado de baja tampoco" do
    # Son dos cosas distintas y las dos cierran la puerta.
    @cliente.update!(activo: false)

    post session_url, params: { email_address: @cliente.codigo, password: "Cliente123!" }

    assert_redirected_to new_session_path
  end

  # ── Los correos de aviso ────────────────────────────────────────────────
  #
  #   > "Ella tiene dos correos, yo no le puedo crear una cuenta aquí porque
  #   >  tiene dos correos."

  test "se le pueden agregar correos para avisarle" do
    delete session_url
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }

    assert_difference "ClienteCorreo.count", 1 do
      patch cliente_url(@cliente), params: { cliente: {
        cliente_correos_attributes: { "0" => { correo: "otro@ejemplo.com" } }
      } }
    end
  end

  test "los correos de aviso NO sirven para entrar" do
    # Es la línea que mantiene una sola llave: el de acceso es uno solo.
    @cliente.cliente_correos.create!(correo: "avisos@ejemplo.com")

    post session_url, params: { email_address: "avisos@ejemplo.com", password: "Cliente123!" }

    assert_redirected_to new_session_path
  end

  test "un correo de aviso no puede repetir el de acceso" do
    correo = ClienteCorreo.new(cliente: @cliente, correo: @cliente.email.upcase)

    assert_not correo.valid?
    assert_match(/correo de acceso/, correo.errors.full_messages.to_sentence)
  end

  test "ni repetirse dentro del mismo cliente" do
    @cliente.cliente_correos.create!(correo: "avisos@ejemplo.com")
    repetido = ClienteCorreo.new(cliente: @cliente, correo: "AVISOS@ejemplo.com")

    assert_not repetido.valid?
  end

  # ── El nombre y el RTN ──────────────────────────────────────────────────
  #
  #   > "Tiene que poner mínimo tres ítems… imaginate cuántos Jorge Padilla hay."

  test "crear un cliente pide nombre y dos apellidos" do
    delete session_url
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }

    assert_no_difference "Cliente.count" do
      post clientes_url, params: { cliente: { nombre: "Jorge", apellido: "Padilla" } }
    end

    assert_response :unprocessable_entity
  end

  test "con tres palabras entra" do
    delete session_url
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }

    assert_difference "Cliente.count", 1 do
      post clientes_url, params: { cliente: { nombre: "Jorge Alejandro", apellido: "Padilla Ferico" } }
    end
  end

  test "pero un cliente viejo de dos palabras se sigue pudiendo editar" do
    # Hay 9.000 importados del sistema viejo y muchos vienen con dos palabras.
    # Abrir uno para corregirle el teléfono no puede trabarse por algo que nadie
    # tocó — la misma trampa del método de prepago y la del consolidado.
    delete session_url
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
    @cliente.update_columns(nombre: "Juan", apellido: "Perez")

    patch cliente_url(@cliente), params: { cliente: { telefono: "9999-8888" } }

    assert_redirected_to cliente_url(@cliente)
    assert_equal "9999-8888", @cliente.reload.telefono
  end

  test "el importador tampoco se entera de la regla" do
    # La regla es de la pantalla donde alguien teclea, no del modelo entero: si
    # no, la migración de los 9.000 se cae de una.
    viejo = Cliente.new(nombre: "Juan", apellido: "Perez", codigo: "CEC-VIEJO")

    assert viejo.valid?, viejo.errors.full_messages.to_sentence
  end

  test "el RTN se guarda y es opcional" do
    delete session_url
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }

    patch cliente_url(@cliente), params: { cliente: { rtn: "08011985123456" } }

    assert_equal "08011985123456", @cliente.reload.rtn
  end
end
