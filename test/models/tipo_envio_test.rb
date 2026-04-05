require "test_helper"

class TipoEnvioTest < ActiveSupport::TestCase
  test "requires nombre" do
    te = TipoEnvio.new(codigo: "foo")
    assert_not te.valid?
    assert te.errors[:nombre].any?
  end

  test "activos scope returns only active tipos" do
    active = tipo_envios(:cer)
    inactive = TipoEnvio.create!(nombre: "Test", codigo: "test-inactive", activo: false)

    result = TipoEnvio.activos
    assert_includes result, active
    assert_not_includes result, inactive
  end

  test "aereos scope returns only aereo modalidad" do
    result = TipoEnvio.aereos
    assert_includes result, tipo_envios(:cer)
    assert_includes result, tipo_envios(:express)
    assert_includes result, tipo_envios(:cka)
    assert_not_includes result, tipo_envios(:cem)
    assert_not_includes result, tipo_envios(:ckm)
  end

  test "maritimos scope returns only maritimo modalidad" do
    result = TipoEnvio.maritimos
    assert_includes result, tipo_envios(:cem)
    assert_includes result, tipo_envios(:ckm)
    assert_not_includes result, tipo_envios(:cer)
    assert_not_includes result, tipo_envios(:express)
  end

  test "single_package? is true only for CKA and CKM" do
    assert tipo_envios(:cka).single_package?
    assert tipo_envios(:ckm).single_package?
    assert_not tipo_envios(:cer).single_package?
    assert_not tipo_envios(:cem).single_package?
    assert_not tipo_envios(:express).single_package?
  end

  test "to_s returns nombre" do
    assert_equal "CER", tipo_envios(:cer).to_s
  end
end
