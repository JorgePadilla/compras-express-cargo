require "test_helper"

# PR-A11Y.2 · La pestaña dice en qué pantalla estás. Es lo primero que lee un
# lector de pantalla al llegar, y de 165 páginas solo 14 ponían su `<title>`:
# el resto se llamaba «Compras Express Cargo». Sale del título de
# PageHeaderComponent.
class TituloDeLaPestanaTest < ActionDispatch::IntegrationTest
  test "el admin: el título del header va a la pestaña" do
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
    get proveedores_path

    assert_select "title", text: "Proveedores · Compras Express Cargo"
  end

  test "el portal del cliente también" do
    post session_url, params: { email_address: clientes(:juan).email, password: "Cliente123!" }
    get cuenta_pre_alertas_path

    assert_select "title", /\A.+ · Compras Express Cargo\z/
    assert_select "title", text: "Mi Cuenta - Compras Express Cargo", count: 0
  end
end
