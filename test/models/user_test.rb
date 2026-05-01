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
    assert_includes user.errors[:nombre], "no puede estar en blanco"
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

  # PR-D2.b: cada rol ve sólo las notas permanentes pensadas para su área.
  test "notas_permanentes_visibles filtra por rol" do
    cajero = User.new(rol: "cajero")
    campos = cajero.notas_permanentes_visibles.map { |n| n[:campo] }
    assert_includes campos, :notas_caja
    assert_not_includes campos, :notas_miami
    assert_not_includes campos, :notas_sac

    miami = User.new(rol: "digitador_miami")
    assert_equal [ :notas_miami ], miami.notas_permanentes_visibles.map { |n| n[:campo] }

    sac = User.new(rol: "sac")
    assert_includes sac.notas_permanentes_visibles.map { |n| n[:campo] }, :notas_sac
  end

  test "notas_permanentes_visibles para admin incluye todas las áreas" do
    admin = User.new(rol: "admin")
    campos = admin.notas_permanentes_visibles.map { |n| n[:campo] }
    assert_equal %i[notas_miami notas_honduras notas_caja notas_sac].sort, campos.sort
  end
end
