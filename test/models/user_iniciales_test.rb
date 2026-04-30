require "test_helper"

# PR-D1.b: User#iniciales editable por admin + iniciales_display fallback.
class UserInicialesTest < ActiveSupport::TestCase
  test "iniciales_display devuelve iniciales custom cuando están seteadas" do
    user = User.new(nombre: "Juan Perez", iniciales: "JP")
    assert_equal "JP", user.iniciales_display
  end

  test "iniciales_display normaliza a uppercase" do
    user = User.new(nombre: "Juan Perez", iniciales: "yg")
    assert_equal "YG", user.iniciales_display
  end

  test "iniciales_display fallback a primeras letras del nombre" do
    user = User.new(nombre: "Yulien Gonzalez")
    assert_equal "YG", user.iniciales_display
  end

  test "iniciales_display fallback con un solo nombre" do
    user = User.new(nombre: "Madonna")
    assert_equal "M", user.iniciales_display
  end

  test "iniciales_display devuelve guion sin nombre" do
    user = User.new(nombre: "")
    assert_equal "—", user.iniciales_display
  end

  test "validacion limita iniciales a 8 chars max" do
    user = User.new(nombre: "X", iniciales: "A" * 9, email_address: "x@test.com", rol: "admin")
    assert_not user.valid?
    assert user.errors[:iniciales].any?
  end

  test "iniciales puede estar vacío (fallback al nombre)" do
    user = User.new(nombre: "X", email_address: "x2@test.com", rol: "admin", iniciales: "")
    user.password = "secret123"
    assert user.valid?
  end
end
