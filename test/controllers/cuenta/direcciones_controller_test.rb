require "test_helper"

# C33-05 · «Mis Direcciones» en el portal: el link del menú apuntaba a `#`.
class Cuenta::DireccionesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cliente = clientes(:juan)
    post session_url, params: { email_address: @cliente.email, password: "Cliente123!" }
  end

  test "el cliente ve su casillero en Miami, uno por servicio, con su codigo" do
    get cuenta_direcciones_url

    assert_response :success
    assert_select "h1", text: /Mis Direcciones/
    assert_select "h2", text: "Miami · CER"
    assert_select "dd", text: "REEMPAQUE AEREO"
    assert_select "dd", text: /\ACEC-001 /
    assert_select "[data-controller=clipboard][data-clipboard-text-value*='Línea 2: REEMPAQUE AEREO']"
  end

  test "el menu del portal lleva a la pagina" do
    get cuenta_root_url

    assert_select "a[href=?]", cuenta_direcciones_path, text: /Mis Direcciones/
  end

  test "sin sesion no entra" do
    delete session_url
    get cuenta_direcciones_url

    assert_response :redirect
  end
end
