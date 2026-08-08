require "test_helper"

# PR-13.c: el PIN de 4 dígitos con el que un supervisor autoriza un cambio de
# precio en la pre-factura.
#
# Yusef: "si lo quieren modificar, ellos tienen que pedir autorización — ahí es
# donde entra un jefe, un supervisor, y ahí es donde llega y pone un código
# especial de él".
class UserPinTest < ActiveSupport::TestCase
  test "el PIN se guarda hasheado, nunca en claro" do
    u = supervisor(pin: "1234")

    assert_not_equal "1234", u.pin_digest
    assert u.pin_digest.start_with?("$2a$"), "tiene que ser bcrypt"
    assert u.authenticate_pin("1234")
    assert_not u.authenticate_pin("4321")
  end

  test "exige exactamente 4 digitos" do
    [ "123", "12345", "abcd", "12a4", "" ].each do |malo|
      u = User.new(base_attrs.merge(pin: malo))
      next if malo.blank?   # vacío significa "sin PIN", no es un error

      assert_not u.valid?, "#{malo.inspect} deberia ser rechazado"
      assert_includes u.errors.full_messages.join(" "), "4 digitos"
    end
  end

  test "el PIN vacio no es un error — la mayoria de los usuarios no lleva" do
    u = User.new(base_attrs.merge(rol: "digitador_miami"))

    assert u.valid?
    assert_nil u.pin_digest
  end

  test "exige confirmacion cuando viene" do
    u = User.new(base_attrs.merge(pin: "1234", pin_confirmation: "9999"))

    assert_not u.valid?
  end

  # ── Quién puede autorizar ───────────────────────────────────────────────

  test "solo los cuatro roles que nombro Yusef pueden autorizar" do
    User::ROLES_AUTORIZANTES.each do |rol|
      assert supervisor(rol: rol, pin: "1234").puede_autorizar?, "#{rol} deberia poder"
    end

    %w[cajero digitador_miami sac supervisor_miami entrega_despacho].each do |rol|
      assert_not supervisor(rol: rol, pin: "1234").puede_autorizar?, "#{rol} NO deberia poder"
    end
  end

  test "sin PIN no autoriza aunque el rol alcance" do
    assert_not supervisor(rol: "supervisor_caja", pin: nil).puede_autorizar?
  end

  test "un usuario inactivo no autoriza" do
    u = supervisor(rol: "supervisor_caja", pin: "1234")
    u.update!(activo: false)

    assert_not u.puede_autorizar?
  end

  test "el scope autorizantes trae solo a los que realmente pueden" do
    puede    = supervisor(rol: "supervisor_caja", pin: "1234")
    sin_pin  = supervisor(rol: "supervisor_caja", pin: nil)
    mal_rol  = supervisor(rol: "cajero", pin: "1234")

    autorizantes = User.autorizantes

    assert_includes autorizantes, puede
    assert_not_includes autorizantes, sin_pin
    assert_not_includes autorizantes, mal_rol
  end

  # ── El PIN inicial del admin ────────────────────────────────────────────

  test "un PIN recien asignado cuenta como sin cambiar" do
    u = supervisor(pin: "1234")

    assert u.pin_sin_cambiar?,
           "mientras no lo cambie, el admin conoce el PIN con el que el autoriza"
  end

  test "deja de contar como sin cambiar cuando el supervisor lo cambia" do
    u = supervisor(pin: "1234")
    u.update!(pin: "5678", pin_cambiado_at: Time.current)

    assert_not u.pin_sin_cambiar?
    assert u.authenticate_pin("5678")
  end

  test "sin PIN no aplica lo de sin cambiar" do
    assert_not supervisor(pin: nil).pin_sin_cambiar?
  end

  # ── El rol nuevo ────────────────────────────────────────────────────────

  test "supervisor_sac existe y ve lo mismo que su equipo" do
    u = supervisor(rol: "supervisor_sac", pin: "1234")

    assert_equal "supervisor_sac", u.rol
    assert_equal "Supervisor de Servicio al Cliente", u.rol_label
    assert u.puede_autorizar?
    assert_equal User.new(rol: "sac").notas_permanentes_visibles,
                 u.notas_permanentes_visibles
  end

  # ── No se mezcla con la contraseña ──────────────────────────────────────

  test "el PIN y la contrasena son credenciales distintas" do
    u = supervisor(pin: "1234")

    assert_not u.authenticate("1234"), "el PIN no debe servir para iniciar sesion"
    assert u.authenticate("password123")
    assert_not u.authenticate_pin("password123")
  end

  test "el audit log no guarda el hash del PIN" do
    u = supervisor(pin: "1234")
    u.update!(pin: "5678", pin_cambiado_at: Time.current)

    cambios = u.versions.last.changeset
    assert_not_includes cambios.keys, "pin_digest"
  end

  private

  def base_attrs
    { nombre: "Prueba", email_address: "pin#{SecureRandom.hex(4)}@cec.test",
      password: "password123", rol: "supervisor_caja", ubicacion: "honduras" }
  end

  def supervisor(rol: "supervisor_caja", pin: "1234")
    User.create!(base_attrs.merge(rol: rol, pin: pin))
  end
end
