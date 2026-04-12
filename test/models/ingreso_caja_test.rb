require "test_helper"

class IngresoCajaTest < ActiveSupport::TestCase
  test "valid with required fields" do
    ingreso = IngresoCaja.new(
      apertura_caja: aperturas_caja(:hoy),
      monto: 100,
      concepto: "Venta de cajas",
      metodo_pago: "efectivo"
    )
    assert ingreso.valid?
  end

  test "requires monto > 0" do
    ingreso = IngresoCaja.new(
      apertura_caja: aperturas_caja(:hoy),
      monto: 0,
      concepto: "Test",
      metodo_pago: "efectivo"
    )
    assert_not ingreso.valid?
  end

  test "requires concepto" do
    ingreso = IngresoCaja.new(
      apertura_caja: aperturas_caja(:hoy),
      monto: 100,
      metodo_pago: "efectivo"
    )
    assert_not ingreso.valid?
    assert_includes ingreso.errors[:concepto], "no puede estar en blanco"
  end

  test "validates metodo_pago inclusion" do
    ingreso = IngresoCaja.new(
      apertura_caja: aperturas_caja(:hoy),
      monto: 100,
      concepto: "Test",
      metodo_pago: "bitcoin"
    )
    assert_not ingreso.valid?
  end

  test "auto-generates numero" do
    ingreso = IngresoCaja.create!(
      apertura_caja: aperturas_caja(:hoy),
      monto: 50,
      concepto: "Test ingreso",
      metodo_pago: "efectivo"
    )
    assert_match /\AIC-\d{6}\z/, ingreso.numero
  end

  test "updates apertura totals after create" do
    apertura = aperturas_caja(:hoy)
    IngresoCaja.create!(
      apertura_caja: apertura,
      monto: 150,
      concepto: "Test",
      metodo_pago: "efectivo"
    )
    apertura.reload
    assert_equal 150.to_d, apertura.total_ingresos.to_d
  end
end
