require "test_helper"

class TarifaRecolectaTest < ActiveSupport::TestCase
  test "valid con zona, monto y moneda" do
    t = TarifaRecolecta.new(zona: "Test Zona", monto: 30, moneda: "USD")
    assert t.valid?
  end

  test "requiere zona" do
    t = TarifaRecolecta.new(monto: 30, moneda: "USD")
    assert_not t.valid?
    assert t.errors[:zona].any?
  end

  test "requiere monto >= 0" do
    t = TarifaRecolecta.new(zona: "Test", monto: -1, moneda: "USD")
    assert_not t.valid?
  end

  test "rechaza moneda fuera del enum" do
    t = TarifaRecolecta.new(zona: "Test", monto: 30, moneda: "EUR")
    assert_not t.valid?
  end

  test "normaliza moneda a mayúsculas" do
    t = TarifaRecolecta.create!(zona: "Test Norm", monto: 30, moneda: "usd")
    assert_equal "USD", t.moneda
  end

  test "scope activas excluye inactivas" do
    activa = TarifaRecolecta.create!(zona: "T-act", monto: 10, moneda: "USD", activo: true)
    inact  = TarifaRecolecta.create!(zona: "T-ina", monto: 10, moneda: "USD", activo: false)
    assert_includes TarifaRecolecta.activas, activa
    assert_not_includes TarifaRecolecta.activas, inact
  end
end
