require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new registration form" do
    get new_registro_url
    assert_response :success
  end

  test "should create client account" do
    assert_difference("Cliente.count") do
      post registro_url, params: { cliente: {
        nombre: "Test", apellido: "User Prueba",
        email: "newclient@test.com", telefono: "99990000",
        password: "Secure123!", password_confirmation: "Secure123!"
      } }
    end
    assert_redirected_to cuenta_root_path
    follow_redirect!
    assert_response :success

    cliente = Cliente.find_by(email: "newclient@test.com")
    assert cliente.activo?
    assert cliente.codigo.present?
  end

  test "should not create client with missing fields" do
    assert_no_difference("Cliente.count") do
      post registro_url, params: { cliente: {
        nombre: "", apellido: "",
        email: "", telefono: "",
        password: "", password_confirmation: ""
      } }
    end
    assert_response :unprocessable_entity
  end

  test "should not create client with short password" do
    assert_no_difference("Cliente.count") do
      post registro_url, params: { cliente: {
        nombre: "Test", apellido: "User Prueba",
        email: "short@test.com", telefono: "99990000",
        password: "short", password_confirmation: "short"
      } }
    end
    assert_response :unprocessable_entity
  end

  test "should not create client with mismatched password" do
    assert_no_difference("Cliente.count") do
      post registro_url, params: { cliente: {
        nombre: "Test", apellido: "User Prueba",
        email: "mismatch@test.com", telefono: "99990000",
        password: "Secure123!", password_confirmation: "Different456!"
      } }
    end
    assert_response :unprocessable_entity
  end

  test "should not create client with duplicate email" do
    existing = clientes(:juan)
    assert_no_difference("Cliente.count") do
      post registro_url, params: { cliente: {
        nombre: "Duplicate", apellido: "Email Prueba",
        email: existing.email, telefono: "99990000",
        password: "Secure123!", password_confirmation: "Secure123!"
      } }
    end
    assert_response :unprocessable_entity
  end

  test "should auto-generate codigo" do
    post registro_url, params: { cliente: {
      nombre: "Auto", apellido: "Code Prueba",
      email: "autocode@test.com", telefono: "99990000",
      password: "Secure123!", password_confirmation: "Secure123!"
    } }
    cliente = Cliente.find_by(email: "autocode@test.com")
    assert_match(/\AC\d+\z/, cliente.codigo)
  end

  # ── La regla de los tres ítems, también acá ─────────────────────────────
  #
  # `PR-C7.33` la puso en `/clientes` y se olvidó de esta pantalla, que es la
  # gemela **y** la de afuera: pública, sin autenticar y linkeada desde el login.
  # Peor: los tests de arriba usaban nombres de dos palabras y **afirmaban que se
  # guardaban**, o sea que congelaban el agujero.
  #
  #   > "Tiene que poner mínimo tres ítems… por lo menos Jorge y dos apellidos."
  #   > "Imaginate cuántos Jorge Padilla hay."

  test "registrarse con nombre de dos palabras no se puede" do
    assert_no_difference("Cliente.count") do
      post registro_url, params: { cliente: {
        nombre: "Jorge", apellido: "Padilla",
        email: "jorge.padilla@test.com", telefono: "99990000",
        password: "Secure123!", password_confirmation: "Secure123!"
      } }
    end
    assert_response :unprocessable_entity
  end

  test "con nombre y dos apellidos si" do
    assert_difference("Cliente.count") do
      post registro_url, params: { cliente: {
        nombre: "Jorge Alejandro", apellido: "Padilla Ferico",
        email: "jorge.completo@test.com", telefono: "99990000",
        password: "Secure123!", password_confirmation: "Secure123!"
      } }
    end
    assert_redirected_to cuenta_root_path
  end

  # Tres palabras repartidas como sea: el modelo cuenta sobre nombre + apellido
  # juntos, no exige dos en cada campo.
  test "tres palabras en el nombre solo tambien alcanzan" do
    assert_difference("Cliente.count") do
      post registro_url, params: { cliente: {
        nombre: "Ana Maria Reyes", apellido: "",
        email: "ana.reyes.tres@test.com", telefono: "99990000",
        password: "Secure123!", password_confirmation: "Secure123!"
      } }
    end
  end

  test "login page should have registration link" do
    get new_session_url
    assert_response :success
    assert_select "a[href=?]", new_registro_path
  end
end
