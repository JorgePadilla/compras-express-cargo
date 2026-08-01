require "test_helper"

# PR-9.c: preferencias de sonido por usuario ("revisar sonidos en Tegus").
class SonidoPreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  test "guarda volumen y on/off" do
    patch preferencia_sonido_url, params: { habilitado: false, volumen: 85 }

    assert_response :success
    @user.reload
    assert_not @user.sonido_habilitado
    assert_equal 85, @user.sonido_volumen
  end

  test "acota el volumen fuera de rango en vez de reventar" do
    patch preferencia_sonido_url, params: { volumen: 500 }
    assert_equal 100, @user.reload.sonido_volumen

    patch preferencia_sonido_url, params: { volumen: -20 }
    assert_equal 0, @user.reload.sonido_volumen
  end

  test "los defaults dejan el sonido encendido" do
    assert @user.sonido_habilitado
    assert_equal 60, @user.sonido_volumen
  end

  test "sin sesion responde unauthorized" do
    delete session_url

    patch preferencia_sonido_url, params: { volumen: 50 }

    assert_includes [ 302, 401 ], response.status
  end
end
