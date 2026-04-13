require "test_helper"

class EgresoCajaTest < ActiveSupport::TestCase
  test "valid with required fields" do
    egreso = EgresoCaja.new(
      apertura_caja: aperturas_caja(:hoy),
      monto: 50,
      concepto: "Combustible",
      metodo_pago: "efectivo"
    )
    assert egreso.valid?
  end

  test "requires monto > 0" do
    egreso = EgresoCaja.new(
      apertura_caja: aperturas_caja(:hoy),
      monto: -5,
      concepto: "Test",
      metodo_pago: "efectivo"
    )
    assert_not egreso.valid?
  end

  test "validates categoria inclusion" do
    egreso = EgresoCaja.new(
      apertura_caja: aperturas_caja(:hoy),
      monto: 50,
      concepto: "Test",
      metodo_pago: "efectivo",
      categoria: "invalida"
    )
    assert_not egreso.valid?
  end

  test "allows blank categoria" do
    egreso = EgresoCaja.new(
      apertura_caja: aperturas_caja(:hoy),
      monto: 50,
      concepto: "Test",
      metodo_pago: "efectivo",
      categoria: ""
    )
    assert egreso.valid?
  end

  test "auto-generates numero" do
    egreso = EgresoCaja.create!(
      apertura_caja: aperturas_caja(:hoy),
      monto: 30,
      concepto: "Suministros",
      metodo_pago: "efectivo",
      categoria: "suministros"
    )
    assert_match /\AEC-\d{6}\z/, egreso.numero
  end

  test "updates apertura totals after create" do
    apertura = aperturas_caja(:hoy)
    EgresoCaja.create!(
      apertura_caja: apertura,
      monto: 75,
      concepto: "Gasolina",
      metodo_pago: "efectivo"
    )
    apertura.reload
    assert_equal 75.to_d, apertura.total_egresos.to_d
  end
end
