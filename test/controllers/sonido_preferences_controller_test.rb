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
    # PR-C29.9 · Desde el 2026-10-08 es la alarma: *"más cruel, fuerte,
    # molesto, intenso"*.
    assert_equal SonidosDeError::DEFAULT, @user.sonido_error_variante, "el default es el de la constante"
  end

  # ── RP-20: la variante del sonido de error ──────────────────────────────

  test "guarda la variante elegida" do
    patch preferencia_sonido_url, params: { variante: "descendente" }

    assert_response :success
    assert_equal "descendente", @user.reload.sonido_error_variante
  end

  test "una variante inventada no guarda nada" do
    # El volumen se acota porque un número tiene a qué acotarse; una variante
    # que no existe, no. Guardar un default silencioso escondería que el JS
    # está mandando basura, y el operario escucharía otro sonido sin saber por
    # qué. Se rechaza entera.
    antes = @user.sonido_error_variante
    patch preferencia_sonido_url, params: { variante: "reggaeton" }

    assert_response :unprocessable_entity
    assert_equal antes, @user.reload.sonido_error_variante
  end

  test "una variante mala no se lleva puesto el volumen del mismo request" do
    patch preferencia_sonido_url, params: { volumen: 90, variante: "reggaeton" }

    assert_response :unprocessable_entity
    assert_equal 60, @user.reload.sonido_volumen, "no se guarda nada si algo del request es inválido"
  end

  test "sin sesion responde unauthorized" do
    delete session_url

    patch preferencia_sonido_url, params: { volumen: 50 }

    assert_includes [ 302, 401 ], response.status
  end

  # ── C29-08 · Un sonido por error ────────────────────────────────────────
  #
  # *"Cada error tiene que tener un tono distinto para que ellos sepan."*

  test "los errores con sonido propio arrancan distintos entre sí y del de siempre" do
    assert_equal "triple", @user.sonido_error_tipo
    assert_equal "agudo", @user.sonido_error_sucursal
  end

  test "guarda con qué suena cada error" do
    patch preferencia_sonido_url, params: { motivos: { tipo_distinto: "descendente", sucursal_distinta: "grave" } },
                                  as: :json

    assert_response :success
    @user.reload
    assert_equal "descendente", @user.sonido_error_tipo
    assert_equal "grave", @user.sonido_error_sucursal
  end

  test "una variante inventada para un error no guarda nada" do
    patch preferencia_sonido_url, params: { motivos: { tipo_distinto: "sirena" } }, as: :json

    assert_response :unprocessable_entity
    assert_equal "triple", @user.reload.sonido_error_tipo
  end
end
