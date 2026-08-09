require "test_helper"

# La misma regla de Yusef, implementada dos veces por caminos distintos.
#
#   "El uno punto cero nueve sigue siendo uno. Uno punto uno ya es uno y medio.
#    Y de uno punto seis ya sube."
#
# `VolumetricoCalculator.half_pound_round` la resuelve en milésimas enteras,
# con dos umbrales explícitos (`< 100` → entero, `< 600` → .5, si no → +1).
# `Tarifa#redondear_al_incremento` la resuelve con aritmética de BigDecimal:
# le resta la tolerancia de 0.09 y hace `ceil` al incremento.
#
# Los dos alimentan la misma factura: el volumétrico define el peso a cobrar,
# la tarifa define por cuánto se cobra. **Si divergen, un paquete se factura
# con un peso y se le busca el escalón con otro.**
#
# Se verificó a mano que coinciden en los 401 pesos de 0.00 a 4.00. Este test
# fija esa coincidencia para que deje de ser una casualidad: si alguien toca
# una de las dos, se entera acá y no en una factura.
#
# No se unifican en una sola implementación a propósito — es código de cobro
# que funciona, y el riesgo de tocarlo es peor que el de tener dos copias
# vigiladas. Si algún día se unifican, este test es el contrato.
class RedondeoMediaLibraCoincideTest < ActiveSupport::TestCase
  test "las dos implementaciones dan lo mismo en todo el rango util" do
    tarifa = Tarifa.new(incremento_libras: 0.5)
    discrepancias = []

    (0..40_000).each do |milesimas|
      next unless (milesimas % 10).zero?   # de 0.00 a 40.00 en pasos de 0.01

      peso = BigDecimal(milesimas) / 1000
      por_tarifa = tarifa.peso_facturable(peso).to_f
      por_volumetrico = VolumetricoCalculator.half_pound_round(peso.to_f)

      discrepancias << [ peso.to_f, por_tarifa, por_volumetrico ] if por_tarifa != por_volumetrico
    end

    assert_empty discrepancias.first(10),
                 "#{discrepancias.size} pesos donde las dos reglas no coinciden " \
                 "(peso, tarifa, volumétrico): #{discrepancias.first(10).inspect}"
  end

  test "los umbrales exactos del audio coinciden en las dos" do
    # Los cuatro puntos que Yusef dictó, uno por uno. Si el rango grande de
    # arriba se rompiera por otra razón, estos dicen cuál umbral se movió.
    tarifa = Tarifa.new(incremento_libras: 0.5)

    { 1.09 => 1.0, 1.10 => 1.5, 1.59 => 1.5, 1.60 => 2.0 }.each do |peso, esperado|
      assert_equal esperado, tarifa.peso_facturable(peso).to_f, "Tarifa falló en #{peso}"
      assert_equal esperado, VolumetricoCalculator.half_pound_round(peso), "Volumétrico falló en #{peso}"
    end
  end
end
