require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid user with all fields" do
    user = User.new(
      nombre: "Test User",
      email_address: "test@example.com",
      password: "password123",
      rol: "admin",
      ubicacion: "miami"
    )
    assert user.valid?
  end

  test "requires nombre" do
    user = User.new(
      email_address: "test@example.com",
      password: "password123",
      rol: "admin"
    )
    assert_not user.valid?
    assert_includes user.errors[:nombre], "can't be blank"
  end

  test "requires unique email" do
    User.create!(
      nombre: "First",
      email_address: "dup@test.com",
      password: "password123",
      rol: "admin",
      ubicacion: "miami"
    )
    user = User.new(
      nombre: "Second",
      email_address: "dup@test.com",
      password: "password123",
      rol: "admin"
    )
    assert_not user.valid?
  end

  test "normalizes email to lowercase" do
    user = User.new(email_address: "  ADMIN@Test.COM  ")
    assert_equal "admin@test.com", user.email_address
  end

  test "enum roles work" do
    user = users(:admin)
    assert user.admin?
    assert_not user.cajero?

    user2 = users(:cajero)
    assert user2.cajero?
    assert_not user2.admin?
  end

  test "enum ubicacion works" do
    user = users(:digitador)
    assert user.miami?
    assert_not user.honduras?
  end

  test "scope activos returns only active users" do
    assert User.activos.all?(&:activo?)
  end

  test "scope por_rol filters by role" do
    admins = User.por_rol(:admin)
    assert admins.all?(&:admin?)
  end

  test "scope en_ubicacion filters by location" do
    miami_users = User.en_ubicacion(:miami)
    assert miami_users.all?(&:miami?)
  end

  test "nombre_completo returns nombre" do
    user = users(:admin)
    assert_equal "Admin Test", user.nombre_completo
  end
end
