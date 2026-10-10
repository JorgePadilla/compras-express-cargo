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

  # PR-F2.1 · El ISV lo calcula la gema con la tarifa general; la columna no
  # puede decir otra cosa, o el PDF imprimiría una tasa que nadie cobra.
  test "isv_rate solo acepta la tarifa general de la gema" do
    emp = Empresa.instance
    emp.isv_rate = 0.18
    assert_not emp.valid?
    assert emp.errors[:isv_rate].any?

    emp.isv_rate = "0.1500"
    assert emp.valid?
    assert_equal Invoicehn::TaxTreatment::GRAVADO_15.rate, IsvAware.rate
  end
end
