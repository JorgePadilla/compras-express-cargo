require "test_helper"

class AperturaCajaTest < ActiveSupport::TestCase
  test "valid with required fields" do
    # Delete today's fixture first
    AperturaCaja.where(fecha: Date.current).delete_all
    apertura = AperturaCaja.new(
      fecha: Date.current,
      monto_apertura: 500,
      abierta_por: users(:cajero)
    )
    assert apertura.valid?
  end

  test "requires unique fecha" do
    apertura = AperturaCaja.new(
      fecha: aperturas_caja(:hoy).fecha,
      monto_apertura: 100,
      abierta_por: users(:cajero)
    )
    assert_not apertura.valid?
    assert apertura.errors[:fecha].any?
  end

  test "monto_apertura must be >= 0" do
    AperturaCaja.where(fecha: Date.current).delete_all
    apertura = AperturaCaja.new(
      fecha: Date.current,
      monto_apertura: -10,
      abierta_por: users(:cajero)
    )
    assert_not apertura.valid?
  end

  test "del_dia returns today's apertura" do
    assert_equal aperturas_caja(:hoy), AperturaCaja.del_dia
  end

  test "abierta_hoy? returns true when open" do
    assert AperturaCaja.abierta_hoy?
  end

  test "total_esperado calculation" do
    a = aperturas_caja(:ayer_cerrada)
    expected = a.monto_apertura.to_d + a.total_pagos.to_d + a.total_ingresos.to_d - a.total_egresos.to_d
    assert_equal expected, a.total_esperado
  end

  test "cerrar! closes the apertura" do
    apertura = aperturas_caja(:hoy)
    assert apertura.cerrar!(monto_cierre: 500, user: users(:cajero), notas: "Todo bien")
    apertura.reload
    assert apertura.cerrada?
    assert_not_nil apertura.cerrada_at
    assert_equal users(:cajero), apertura.cerrada_por
  end

  test "cannot cerrar already closed" do
    apertura = aperturas_caja(:ayer_cerrada)
    assert_not apertura.cerrar!(monto_cierre: 100, user: users(:cajero))
  end

  test "auto-generates numero" do
    AperturaCaja.where(fecha: Date.current).delete_all
    apertura = AperturaCaja.create!(
      fecha: Date.current,
      monto_apertura: 100,
      abierta_por: users(:cajero)
    )
    assert_match /\AAC-\d{6}\z/, apertura.numero
  end
end
