require "test_helper"

class EmpresaTest < ActiveSupport::TestCase
  test "instance returns the singleton" do
    emp = Empresa.instance
    assert_kind_of Empresa, emp
    assert emp.persisted?
    assert_equal emp.id, Empresa.instance.id
  end

  test "instance is idempotent" do
    assert_no_difference "Empresa.count" do
      Empresa.instance
      Empresa.instance
    end
  end

  test "validates nombre presence" do
    emp = Empresa.instance
    emp.nombre = nil
    assert_not emp.valid?
  end

  test "validates isv_rate range" do
    emp = Empresa.instance
    emp.isv_rate = 1.5
    assert_not emp.valid?

    emp.isv_rate = -0.01
    assert_not emp.valid?

    emp.isv_rate = 0.15
    assert emp.valid?
  end
end
