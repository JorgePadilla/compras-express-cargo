require "test_helper"

# PR-A11Y.5 · Las regiones `aria-live` existen desde que carga la página: una
# que aparece junto con su texto no se escucha. Las dos gemelas.
class RegionesDelLectorTest < ActionDispatch::IntegrationTest
  test "el admin las tiene" do
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
    get proveedores_path

    assert_select "#aviso-lector[role=status][aria-live=polite]"
    assert_select "#aviso-lector-urgente[role=alert][aria-live=assertive]"
  end

  test "el portal también" do
    post session_url, params: { email_address: clientes(:juan).email, password: "Cliente123!" }
    get cuenta_pre_alertas_path

    assert_select "#aviso-lector[role=status][aria-live=polite]"
    assert_select "#aviso-lector-urgente[role=alert][aria-live=assertive]"
  end
end
