require "test_helper"

# PR-13.c: el supervisor cambia su propio PIN.
#
# El admin asigna el inicial, pero mientras el supervisor no lo cambie el admin
# conoce el PIN con el que él autoriza — y ahí el registro de "quién autorizó"
# deja de probar nada. Esta pantalla es la que cierra eso.
class PinsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @supervisor = User.create!(
      nombre: "Supervisora Caja", email_address: "supcaja@cec.test",
      password: "password123", rol: "supervisor_caja", ubicacion: "honduras",
      pin: "1234"
    )
  end

  test "el supervisor cambia su PIN dando el actual" do
    login(@supervisor)

    patch mi_pin_url, params: { user: { pin_actual: "1234", pin: "5678", pin_confirmation: "5678" } }

    assert_redirected_to root_path
    @supervisor.reload
    assert @supervisor.authenticate_pin("5678")
    assert_not @supervisor.pin_sin_cambiar?
  end

  test "con el PIN actual equivocado no cambia nada" do
    login(@supervisor)

    patch mi_pin_url, params: { user: { pin_actual: "0000", pin: "5678", pin_confirmation: "5678" } }

    assert_response :unprocessable_entity
    assert @supervisor.reload.authenticate_pin("1234"), "el PIN no debio cambiar"
  end

  test "rechaza un PIN que no sean 4 digitos" do
    login(@supervisor)

    patch mi_pin_url, params: { user: { pin_actual: "1234", pin: "12", pin_confirmation: "12" } }

    assert_response :unprocessable_entity
    assert @supervisor.reload.authenticate_pin("1234")
  end

  test "rechaza cuando la confirmacion no coincide" do
    login(@supervisor)

    patch mi_pin_url, params: { user: { pin_actual: "1234", pin: "5678", pin_confirmation: "8765" } }

    assert_response :unprocessable_entity
    assert @supervisor.reload.authenticate_pin("1234")
  end

  test "le avisa al supervisor que todavia tiene el PIN del admin" do
    login(@supervisor)

    get edit_mi_pin_url

    assert_response :success
    assert_match "PIN que te asigno el administrador", response.body
    assert_match "autorizar en tu nombre", response.body
  end

  test "el aviso desaparece cuando ya lo cambio" do
    @supervisor.update!(pin: "5678", pin_cambiado_at: Time.current)
    login(@supervisor)

    get edit_mi_pin_url

    assert_response :success
    assert_no_match(/PIN que te asigno el administrador/, response.body)
  end

  test "el link al PIN sale en el sidebar solo para quien autoriza" do
    login(@supervisor)
    get root_url
    assert_match "Cambiá tu PIN", response.body, "con PIN sin cambiar, avisa"

    @supervisor.update!(pin: "5678", pin_cambiado_at: Time.current)
    get root_url
    assert_match "Mi PIN", response.body

    login(users(:digitador))
    get etiquetar_url
    assert_no_match(/Mi PIN/, response.body, "un digitador no usa PIN")
  end

  test "un rol que no autoriza no entra a la pantalla" do
    login(users(:cajero))

    get edit_mi_pin_url

    assert_redirected_to root_path
  end

  test "quien todavia no tiene PIN ve que se lo pida al admin" do
    sin_pin = User.create!(
      nombre: "Sin PIN", email_address: "sinpin@cec.test", password: "password123",
      rol: "supervisor_prefactura", ubicacion: "honduras"
    )
    login(sin_pin)

    get edit_mi_pin_url
    assert_response :success
    assert_match "administrador", response.body

    # Y no puede auto-asignarse uno por la puerta de atrás.
    patch mi_pin_url, params: { user: { pin_actual: "", pin: "1111", pin_confirmation: "1111" } }
    assert_nil sin_pin.reload.pin_digest
  end

  test "el PIN no queda en el log" do
    filtro = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtrado = filtro.filter("pin" => "1234", "pin_confirmation" => "1234", "pin_actual" => "9999")

    assert_equal "[FILTERED]", filtrado["pin"],
                 "el PIN habilita mover plata; no puede quedar en texto plano en el log"
    assert_equal "[FILTERED]", filtrado["pin_confirmation"]
    assert_equal "[FILTERED]", filtrado["pin_actual"]
  end

  private

  def login(user)
    delete session_url
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end
end
