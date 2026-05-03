require "test_helper"

class SidebarPreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  test "actualiza collapsed para el usuario autenticado" do
    patch preferencia_sidebar_url, params: { collapsed: false }, as: :json
    assert_response :success
    assert_equal false, @user.reload.sidebar_collapsed
  end

  test "actualiza pinned" do
    patch preferencia_sidebar_url, params: { pinned: true }, as: :json
    assert_response :success
    assert_equal true, @user.reload.sidebar_pinned
  end

  test "actualiza position a right" do
    patch preferencia_sidebar_url, params: { position: "right" }, as: :json
    assert_response :success
    assert_equal "right", @user.reload.sidebar_position
  end

  test "actualiza position a left" do
    @user.update_column(:sidebar_position, "right")
    patch preferencia_sidebar_url, params: { position: "left" }, as: :json
    assert_response :success
    assert_equal "left", @user.reload.sidebar_position
  end

  test "position invalida se ignora" do
    patch preferencia_sidebar_url, params: { position: "top" }, as: :json
    assert_response :success
    assert_equal "left", @user.reload.sidebar_position # default sin cambio
  end

  test "PATCH multiples campos a la vez" do
    patch preferencia_sidebar_url, params: { collapsed: false, pinned: true, position: "right" }, as: :json
    assert_response :success
    @user.reload
    assert_equal false, @user.sidebar_collapsed
    assert_equal true,  @user.sidebar_pinned
    assert_equal "right", @user.sidebar_position
  end

  test "sin autenticacion redirige al login" do
    delete session_url
    patch preferencia_sidebar_url, params: { pinned: true }
    assert_redirected_to new_session_path
  end
end
