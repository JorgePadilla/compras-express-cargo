require "test_helper"

# PR-C29.16 · «Signos del servidor»: solo admin.
class SignosVitalesControllerTest < ActionDispatch::IntegrationTest
  def login_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  test "admin ve las cuatro secciones y el estado general" do
    login_as users(:admin)
    get signos_vitales_url
    assert_response :success

    %w[servidor base cola app].each { |clave| assert_select "section[data-seccion=#{clave}]" }
    assert_select "[data-nivel]"
    assert_select "turbo-frame#signos_vitales[data-controller=refresco]"
  end

  test "no muestra secretos: nada del DATABASE_URL ni de las claves" do
    login_as users(:admin)
    get signos_vitales_url
    assert_no_match(/postgres:\/\//, response.body)
    assert_no_match(/SECRET_KEY_BASE|RAILS_MASTER_KEY/, response.body)
  end

  test "un supervisor no entra" do
    login_as users(:supervisor_miami)
    get signos_vitales_url
    assert_redirected_to root_path
  end

  test "un digitador no entra" do
    login_as users(:digitador)
    get signos_vitales_url
    assert_redirected_to root_path
  end

  test "el Home le muestra el ícono al admin, con su semáforo" do
    login_as users(:admin)
    get root_url
    assert_select "a[href='#{signos_vitales_path}'][data-signos]"
  end

  test "el Home no le muestra el ícono a un supervisor" do
    login_as users(:supervisor_miami)
    get root_url
    assert_response :success
    assert_select "a[href='#{signos_vitales_path}']", count: 0
  end
end
