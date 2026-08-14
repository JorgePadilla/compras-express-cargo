require "test_helper"

# El total de libras a cobrar del Warehouse Receipt — `PR-C7.16`.
#
# Yusef, audio del 2026-08-13, explicando qué le falta al WR:
#
#   > "Aquí es donde le tenés que poner la medida de las tres cajas, el total de
#   >  las tres cajas… el valor total de libras que se le va a cobrar. **No es
#   >  valor de precios, sino es valor de libras** que se le va a cobrar, el que
#   >  sea mayor en cada transacción. O sea, si una caja pesa más y la otra tiene
#   >  más volumen, entonces le vas poniendo el de mayor **de cada una
#   >  individual**."
#
# O sea: **suma de los máximos por caja**, no el máximo de las sumas.
class WarehouseReceiptTotalesTest < ActionView::TestCase
  include WarehouseReceiptHelper

  setup do
    @cliente = clientes(:juan)
    @cer     = tipo_envios(:cer)
  end

  def caja(peso:, alto:, largo:, ancho:)
    Paquete.create!(cliente: @cliente, tipo_envio: @cer, tracking: "1Z#{SecureRandom.hex(4)}",
                    peso: peso, alto: alto, largo: largo, ancho: ancho,
                    user: users(:admin), estado: "recibido_miami")
  end

  # El caso que él describió: una caja pesa más, la otra tiene más volumen.
  # Los dos números **no coinciden**, y por eso hacía falta la fila.
  test "suma el mayor de cada caja, no el mayor de las sumas" do
    pesada     = caja(peso: 5, alto: 10, largo: 5,  ancho: 15)   # real 5.0  · vol 4.5
    voluminosa = caja(peso: 2, alto: 30, largo: 30, ancho: 30)   # real 2.0  · vol 162.65 → 163
    paquetes   = [ pesada, voluminosa ]

    totales = wr_totals(paquetes)

    esperado = pesada.peso_cobrar.to_f + voluminosa.peso_cobrar.to_f
    assert_equal esperado.round(2), totales[:chargeable_lb]

    mayor_de_las_sumas = [ totales[:weight_lb], totales[:vol_weight_lb] ].max
    assert_not_equal mayor_de_las_sumas, totales[:chargeable_lb],
                     "si dieran lo mismo, este test no estaría probando la regla de Yusef"
  end

  # `peso_cobrar` ya lo persiste `calculate_peso_cobrar` con la regla completa
  # —incluido el trato de solo-volumétrico del cliente—. El helper **suma**, no
  # reimplementa: reimplementarla sería recrear la duplicación que PR-C7.11 mató.
  test "usa el peso a cobrar que ya calculo el paquete" do
    c = caja(peso: 5, alto: 10, largo: 5, ancho: 15)
    c.update_columns(peso_cobrar: 99)

    assert_equal 99.0, wr_totals([ c.reload ])[:chargeable_lb]
  end

  test "cuenta una pieza por caja" do
    paquetes = [ caja(peso: 1, alto: 2, largo: 2, ancho: 2),
                 caja(peso: 1, alto: 2, largo: 2, ancho: 2),
                 caja(peso: 1, alto: 2, largo: 2, ancho: 2) ]

    assert_equal 3, wr_totals(paquetes)[:pieces]
  end

  test "expone el equivalente en kilos, como las otras filas" do
    c = caja(peso: 10, alto: 1, largo: 1, ancho: 1)

    totales = wr_totals([ c ])
    assert_in_delta totales[:chargeable_lb] * 0.4535924, totales[:chargeable_kg], 0.01
  end
end
