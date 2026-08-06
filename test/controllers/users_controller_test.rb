require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    post session_url, params: { email_address: @admin.email_address, password: "password123" }
  end

  # --- Admin access ---

  test "admin should get index" do
    get users_url
    assert_response :success
  end

  test "admin should search users" do
    get users_url, params: { q: "Admin" }
    assert_response :success
  end

  test "admin should get new" do
    get new_user_url
    assert_response :success
  end

  test "admin should create user" do
    assert_difference("User.count") do
      post users_url, params: { user: {
        nombre: "Nuevo Usuario", email_address: "nuevo@test.com",
        password: "password123", password_confirmation: "password123",
        rol: "cajero", ubicacion: "honduras"
      } }
    end
    assert_redirected_to user_url(User.last)
  end

  test "admin should not create user with invalid data" do
    assert_no_difference("User.count") do
      post users_url, params: { user: { nombre: "", email_address: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "admin should show user" do
    get user_url(@admin)
    assert_response :success
  end

  test "admin should get edit" do
    get edit_user_url(@admin)
    assert_response :success
  end

  test "admin should update user" do
    user = users(:cajero)
    patch user_url(user), params: { user: { nombre: "Updated Name" } }
    assert_redirected_to user_url(user)
    user.reload
    assert_equal "Updated Name", user.nombre
  end

  test "admin should update user without changing password" do
    user = users(:cajero)
    original_digest = user.password_digest
    patch user_url(user), params: { user: { nombre: "No Password Change", password: "", password_confirmation: "" } }
    assert_redirected_to user_url(user)
    user.reload
    assert_equal "No Password Change", user.nombre
    assert_equal original_digest, user.password_digest
  end

  test "admin should update user password" do
    user = users(:cajero)
    original_digest = user.password_digest
    patch user_url(user), params: { user: { password: "newpassword123", password_confirmation: "newpassword123" } }
    assert_redirected_to user_url(user)
    user.reload
    assert_not_equal original_digest, user.password_digest
  end

  test "admin should not update with invalid data" do
    user = users(:cajero)
    patch user_url(user), params: { user: { nombre: "" } }
    assert_response :unprocessable_entity
  end

  test "admin should toggle activo" do
    user = users(:cajero)
    patch user_url(user), params: { user: { activo: false } }
    assert_redirected_to user_url(user)
    user.reload
    assert_not user.activo?
  end

  # --- Non-admin access denied ---

  test "non-admin should be redirected from index" do
    delete session_url
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }

    get users_url
    assert_redirected_to root_path
  end

  test "non-admin should be redirected from new" do
    delete session_url
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }

    get new_user_url
    assert_redirected_to root_path
  end

  test "non-admin should be redirected from create" do
    delete session_url
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }

    assert_no_difference("User.count") do
      post users_url, params: { user: {
        nombre: "Hacker", email_address: "hack@test.com",
        password: "password123", password_confirmation: "password123",
        rol: "admin"
      } }
    end
    assert_redirected_to root_path
  end

  test "unauthenticated user should be redirected to login" do
    delete session_url
    get users_url
    assert_redirected_to new_session_url
  end

  # --- PIN de autorizacion (PR-13.c) ---

  test "el admin le asigna el PIN inicial a un supervisor" do
    supervisor = User.create!(
      nombre: "Sup", email_address: "sup13c@cec.test", password: "password123",
      rol: "supervisor_prefactura", ubicacion: "honduras"
    )

    patch user_url(supervisor), params: { user: { pin: "4321", pin_confirmation: "4321" } }

    supervisor.reload
    assert supervisor.authenticate_pin("4321")
    assert supervisor.pin_sin_cambiar?, "recien asignado por el admin, todavia no lo cambio el"
  end

  test "un PIN vacio mantiene el que ya tenia" do
    supervisor = User.create!(
      nombre: "Sup2", email_address: "sup13c2@cec.test", password: "password123",
      rol: "supervisor_caja", ubicacion: "honduras", pin: "1111"
    )

    patch user_url(supervisor), params: { user: { nombre: "Sup2 editada", pin: "", pin_confirmation: "" } }

    supervisor.reload
    assert_equal "Sup2 editada", supervisor.nombre
    assert supervisor.authenticate_pin("1111"), "no debio borrarse por venir vacio"
  end

  test "reasignar el PIN lo vuelve a marcar como sin cambiar" do
    supervisor = User.create!(
      nombre: "Sup3", email_address: "sup13c3@cec.test", password: "password123",
      rol: "supervisor_caja", ubicacion: "honduras", pin: "1111",
      pin_cambiado_at: Time.current
    )
    assert_not supervisor.pin_sin_cambiar?

    patch user_url(supervisor), params: { user: { pin: "2222", pin_confirmation: "2222" } }

    assert supervisor.reload.pin_sin_cambiar?,
           "si el admin lo reasigna, vuelve a conocerlo hasta que el supervisor lo cambie"
  end
end
