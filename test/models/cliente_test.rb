require "test_helper"

class ClienteTest < ActiveSupport::TestCase
  test "valid cliente with required fields" do
    cliente = Cliente.new(nombre: "Test", codigo: "CEC-999")
    assert cliente.valid?
  end

  test "requires nombre" do
    cliente = Cliente.new(codigo: "CEC-999")
    assert_not cliente.valid?
    assert_includes cliente.errors[:nombre], "no puede estar en blanco"
  end

  test "requires unique codigo" do
    assert_equal "CEC-001", clientes(:juan).codigo
    cliente = Cliente.new(nombre: "Duplicate", codigo: "CEC-001")
    assert_not cliente.valid?
    assert_includes cliente.errors[:codigo], "ya esta en uso"
  end

  test "codigo uniqueness is case insensitive" do
    cliente = Cliente.new(nombre: "Test", codigo: "cec-001")
    assert_not cliente.valid?
  end

  test "validates email format" do
    cliente = Cliente.new(nombre: "Test", codigo: "CEC-999", email: "bad-email")
    assert_not cliente.valid?
    assert_includes cliente.errors[:email], "no es un formato de correo valido"
  end

  test "allows blank email" do
    cliente = Cliente.new(nombre: "Test", codigo: "CEC-999", email: "")
    assert cliente.valid?
  end

  test "auto-generates codigo on create" do
    cliente = Cliente.create!(nombre: "Auto Code")
    assert_match /\ACEC-\d{3}\z/, cliente.codigo
  end

  test "auto-generated codigo increments" do
    # Fixtures have CEC-001, CEC-002, CEC-003
    cliente = Cliente.create!(nombre: "Next")
    assert_equal "CEC-004", cliente.codigo
  end

  test "scope activos returns only active clients" do
    activos = Cliente.activos
    assert activos.all?(&:activo?)
    assert_not_includes activos, clientes(:inactivo)
  end

  test "scope buscar searches by codigo" do
    results = Cliente.buscar("CEC-001")
    assert_includes results, clientes(:juan)
    assert_not_includes results, clientes(:maria)
  end

  test "scope buscar searches by nombre" do
    results = Cliente.buscar("Maria")
    assert_includes results, clientes(:maria)
  end

  test "scope buscar searches by email" do
    results = Cliente.buscar("juan@example")
    assert_includes results, clientes(:juan)
  end

  test "nombre_completo joins nombre and apellido" do
    assert_equal "Juan Perez", clientes(:juan).nombre_completo
  end

  test "nombre_completo with only nombre" do
    cliente = Cliente.new(nombre: "Solo")
    assert_equal "Solo", cliente.nombre_completo
  end

  test "belongs to categoria_precio optionally" do
    assert_equal "Regular", clientes(:juan).categoria_precio.nombre
    cliente = Cliente.new(nombre: "No Cat", codigo: "CEC-999")
    assert_nil cliente.categoria_precio
    assert cliente.valid?
  end
end
