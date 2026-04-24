require "test_helper"

class ThemePreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  test "actualiza tema a dark para el usuario autenticado" do
    patch preferencia_tema_url, params: { tema: "dark" }, as: :json
    assert_response :success
    assert_equal "dark", @user.reload.tema
  end

  test "actualiza tema a light" do
    @user.update_column(:tema, "dark")
    patch preferencia_tema_url, params: { tema: "light" }, as: :json
    assert_response :success
    assert_equal "light", @user.reload.tema
  end

  test "tema vacio pone nil (auto)" do
    @user.update_column(:tema, "dark")
    patch preferencia_tema_url, params: { tema: "" }, as: :json
    assert_response :success
    assert_nil @user.reload.tema
  end

  test "tema invalido se ignora y se guarda nil" do
    patch preferencia_tema_url, params: { tema: "neon" }, as: :json
    assert_response :success
    assert_nil @user.reload.tema
  end

  test "sin autenticacion redirige al login" do
    delete session_url
    patch preferencia_tema_url, params: { tema: "dark" }
    assert_redirected_to new_session_path
  end
end
