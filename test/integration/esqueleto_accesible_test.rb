require "test_helper"

# PR-A11Y.3 · Lo que el lector de pantalla encuentra antes del contenido.
class EsqueletoAccesibleTest < ActionDispatch::IntegrationTest
  test "admin: un solo h1, el del header; el link activo con aria-current; el menú con nombre" do
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
    get proveedores_path

    assert_select "h1", count: 1
    assert_select "h1", text: "Proveedores"
    assert_select "nav[aria-label='Menú principal']"
    assert_select "#sidebar a[aria-current='page'][href='#{proveedores_path}']"
    assert_select "#sidebar a[aria-current]", count: 1
    assert_select "a[href='#contenido']", text: "Saltar al contenido"
    assert_select "#contenido[tabindex='-1']"
  end

  test "las secciones del menú son listas con nombre" do
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
    get proveedores_path

    assert_select "#sidebar ul[aria-labelledby='sidebar-seccion-miami']"
    assert_select "#sidebar-seccion-miami", text: "Miami"
  end

  test "portal: la gemela" do
    post session_url, params: { email_address: clientes(:juan).email, password: "Cliente123!" }
    get cuenta_pre_alertas_path

    assert_select "h1", count: 1
    assert_select "nav[aria-label='Menú de tu cuenta']"
    assert_select "a[href='#contenido']", text: "Saltar al contenido"
    assert_select "button[aria-controls='sidebar'][aria-expanded='false']"
  end
end
