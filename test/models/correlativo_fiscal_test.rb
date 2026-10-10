require "test_helper"

# PR-F1.1 · El contador por punto y tipo.
class CorrelativoFiscalTest < ActiveSupport::TestCase
  test "uno por punto y tipo, en el modelo y en la base" do
    repetido = CorrelativoFiscal.new(punto_de_emision: puntos_de_emision(:sps), tipo_documento: "01")
    assert_not repetido.valid?
    assert_raises(ActiveRecord::RecordNotUnique) { repetido.save!(validate: false) }

    assert CorrelativoFiscal.create!(punto_de_emision: puntos_de_emision(:sps), tipo_documento: "06")
  end

  test "arranca en cero y el siguiente es uno" do
    c = CorrelativoFiscal.create!(punto_de_emision: puntos_de_emision(:tgu), tipo_documento: "01")
    assert_equal 0, c.ultimo
    assert_equal 1, c.siguiente
  end

  test "no baja de cero ni pasa de 99999999, tampoco salteando el modelo" do
    c = correlativos_fiscales(:sps_factura)
    c.ultimo = -1
    assert_not c.valid?
    c.ultimo = 100_000_000
    assert_not c.valid?

    error = assert_raises(ActiveRecord::StatementInvalid) { c.save!(validate: false) }
    assert_kind_of PG::CheckViolation, error.cause
  end
end
