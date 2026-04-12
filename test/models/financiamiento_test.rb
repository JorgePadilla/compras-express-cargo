require "test_helper"

class FinanciamientoTest < ActiveSupport::TestCase
  setup do
    @venta = ventas(:pendiente_juan)
    @cliente = clientes(:juan)
    @user = users(:cajero)
  end

  test "auto-generates numero on create" do
    fn = Financiamiento.create!(
      venta: @venta, cliente: @cliente, numero_cuotas: 3,
      monto_total: 100, frecuencia: "mensual", fecha_inicio: Date.current
    )
    assert_match /\AFN-\d{6}\z/, fn.numero
  end

  test "auto-calculates monto_cuota" do
    fn = Financiamiento.create!(
      venta: @venta, cliente: @cliente, numero_cuotas: 4,
      monto_total: 100, frecuencia: "mensual", fecha_inicio: Date.current
    )
    assert_equal 25.to_d, fn.monto_cuota.to_d
  end

  test "generar_cuotas! creates correct number of cuotas" do
    fn = Financiamiento.create!(
      venta: @venta, cliente: @cliente, numero_cuotas: 3,
      monto_total: 90, frecuencia: "mensual", fecha_inicio: Date.current
    )
    fn.generar_cuotas!
    assert_equal 3, fn.financiamiento_cuotas.count
    assert_equal 30.to_d, fn.financiamiento_cuotas.first.monto.to_d
  end

  test "generar_cuotas! sets correct dates for weekly frequency" do
    fn = Financiamiento.create!(
      venta: @venta, cliente: @cliente, numero_cuotas: 3,
      monto_total: 90, frecuencia: "semanal", fecha_inicio: Date.current
    )
    fn.generar_cuotas!
    cuotas = fn.financiamiento_cuotas.order(:numero_cuota)
    assert_equal Date.current, cuotas.first.fecha_vencimiento
    assert_equal Date.current + 7.days, cuotas.second.fecha_vencimiento
    assert_equal Date.current + 14.days, cuotas.third.fecha_vencimiento
  end

  test "verificar_completado! transitions to completado when all paid" do
    fn = financiamientos(:activo_juan)
    fn.financiamiento_cuotas.update_all(estado: "pagada", pagada_at: Time.current)
    fn.verificar_completado!
    assert fn.reload.completado?
  end

  test "cancelar! transitions activo to cancelado" do
    fn = financiamientos(:activo_juan)
    assert fn.cancelar!
    assert fn.cancelado?
  end

  test "cancelar! fails for non-activo" do
    fn = financiamientos(:activo_juan)
    fn.update!(estado: "completado")
    assert_not fn.cancelar!
  end

  test "progreso_porcentaje" do
    fn = financiamientos(:activo_juan)
    assert_equal 0, fn.progreso_porcentaje
    fn.financiamiento_cuotas.first.update!(estado: "pagada")
    assert_equal 33, fn.progreso_porcentaje
  end

  test "monto_pagado and monto_pendiente" do
    fn = financiamientos(:activo_juan)
    assert_equal 0, fn.monto_pagado.to_d
    assert_equal fn.monto_total.to_d, fn.monto_pendiente.to_d
    fn.financiamiento_cuotas.first.update!(estado: "pagada")
    assert_equal fn.monto_cuota.to_d, fn.monto_pagado.to_d
  end

  test "marcar_cuotas_vencidas! updates overdue cuotas" do
    fn = financiamientos(:activo_juan)
    cuota = fn.financiamiento_cuotas.first
    cuota.update!(fecha_vencimiento: 1.day.ago)
    Financiamiento.marcar_cuotas_vencidas!
    assert_equal "vencida", cuota.reload.estado
  end
end
