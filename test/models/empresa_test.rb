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

  # QA de PR-F2.1 · La validación frena lo que se guarda de acá en adelante,
  # no la fila que ya está. Si la base tuviera otra tasa, nadie que calcule o
  # rotule el ISV la puede leer: todos van a `IsvAware.rate`.
  test "una fila vieja con otra tasa no separa el mínimo con ISV, el PDF ni los totales" do
    Empresa.instance.update_columns(isv_rate: 0.18)

    tarifa = Tarifa.new(minimo_monto: BigDecimal("173.91"))
    assert_equal BigDecimal("200.0"), tarifa.minimo_monto_con_isv, "el mínimo con ISV, con el 15 de la gema"
    assert_equal BigDecimal("0.15"), IsvAware.rate
    pdf_src = File.read(Rails.root.join("app/pdfs/application_pdf.rb"))
    assert_no_match(/empresa\.isv_rate/, pdf_src, "el rótulo del PDF no lee la columna")
  end
end
