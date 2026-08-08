require "test_helper"

# PR-C6.2: el redondeo de libras cobraba de más.
#
# Yusef dictó la regla en el audio de precios:
#
#   "El uno punto cero nueve **sigue siendo uno**. Uno punto uno ya es **uno y
#    medio**. Uno y medio pues uno y medio. Y de **uno punto seis ya sube**."
#
# O sea que los umbrales son `.10` y `.60`. Hay una tolerancia de 9 centésimas
# de libra — la báscula tiembla y no se le cobra media libra a alguien por 30
# gramos.
#
# `redondear_al_incremento` era un `ceil` puro, y un ceil no tiene tolerancia:
# fallaba en las bandas `.01–.09` y `.51–.59`, **siempre hacia arriba**.
#
# Estaba latente porque `incremento_libras` viene en `nil` en las 58 tarifas
# cargadas. Muerde el día que Yusef active el escalonado — y lo va a activar él
# mismo, porque los precios los carga su equipo.
class TarifaRedondeoTest < ActiveSupport::TestCase
  # La tabla exacta del audio, con incremento de media libra.
  CASOS = {
    "1.00" => "1.0",
    "1.05" => "1.0",   # el ceil daba 1.5
    "1.09" => "1.0",   # el ceil daba 1.5
    "1.10" => "1.5",
    "1.30" => "1.5",
    "1.50" => "1.5",
    "1.55" => "1.5",   # el ceil daba 2.0
    "1.59" => "1.5",   # el ceil daba 2.0
    "1.60" => "2.0",
    "1.90" => "2.0",
    "2.00" => "2.0"
  }.freeze

  test "la regla .10 y .60 que dicto Yusef" do
    t = Tarifa.new(incremento_libras: 0.5)

    CASOS.each do |peso, esperado|
      real = t.send(:redondear_al_incremento, BigDecimal(peso))
      assert_equal BigDecimal(esperado), real,
                   "#{peso} lb tendría que cobrarse como #{esperado}, no #{real.to_f}"
    end
  end

  test "sin incremento no se redondea nada" do
    # Es el estado de hoy: las 58 tarifas cargadas tienen `incremento_libras`
    # en nil, así que se cobra el peso exacto. Este test fija que el cambio no
    # tocó ese camino.
    t = Tarifa.new(incremento_libras: nil)

    assert_equal BigDecimal("1.37"), t.send(:redondear_al_incremento, BigDecimal("1.37"))
  end

  test "un peso menor que la tolerancia no se vuelve negativo" do
    # 0.05 lb menos la tolerancia da negativo. Sin el guard, el ceil de un
    # negativo devolvía 0 o -0.5 según el redondeo — y un peso negativo en una
    # factura es peor que uno mal redondeado.
    t = Tarifa.new(incremento_libras: 0.5)

    assert_operator t.send(:redondear_al_incremento, BigDecimal("0.05")), :>=, 0
    assert_operator t.send(:redondear_al_incremento, BigDecimal("0.09")), :>=, 0
  end

  test "con incremento de una libra entera la tolerancia sigue siendo 0.09" do
    # Documenta el comportamiento actual, que es la lectura literal del audio.
    # Yusef describió la regla SOLO para media libra; si algún día crea una
    # tarifa con incremento de 1 lb hay que preguntarle si la tolerancia
    # cambia. Este test existe para que ese cambio sea deliberado y no un
    # efecto colateral.
    t = Tarifa.new(incremento_libras: 1)

    assert_equal BigDecimal("1.0"), t.send(:redondear_al_incremento, BigDecimal("1.09"))
    assert_equal BigDecimal("2.0"), t.send(:redondear_al_incremento, BigDecimal("1.10"))
  end

  test "el cobro real usa el peso redondeado" do
    # El camino completo: `cobro_para` redondea antes de multiplicar.
    t = Tarifa.new(incremento_libras: 0.5, precio_libra: 10, moneda: "USD",
                   aplica_minimo: false)

    # 1.09 lb → 1.0 lb × $10 = $10, no 1.5 × 10 = $15.
    assert_equal BigDecimal("10.00"), t.cobro_para(BigDecimal("1.09"))[:subtotal]
    assert_equal BigDecimal("1.0"),   t.cobro_para(BigDecimal("1.09"))[:peso_facturado]
  end
end
