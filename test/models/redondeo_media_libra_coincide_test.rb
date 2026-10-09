require "test_helper"

# La regla de la media libra de Yusef, y que **haya una sola**.
#
#   "El uno punto cero nueve sigue siendo uno. Uno punto uno ya es uno y medio.
#    Y de uno punto seis ya sube."
#
# Este archivo nació vigilando dos implementaciones: `VolumetricoCalculator` la
# resolvía en milésimas enteras y `Tarifa#redondear_al_incremento` restando una
# tolerancia de 0.09 y haciendo `ceil`. Decía, textualmente, *"no se unifican a
# propósito… si algún día se unifican, este test es el contrato"*.
#
# **Ese día llegó, y llegó porque las dos no daban lo mismo.** El barrido de
# abajo iba en pasos de 0.01, y las dos versiones coincidían en todo peso de dos
# decimales — restar 0.09 y "por debajo de .10" solo se separan en el tercero:
#
#   | peso  | Tarifa (antes) | Volumétrico | hoja de Yusef |
#   |-------|----------------|-------------|---------------|
#   | 3.099 | 3.5            | 3.0         | **3**         |
#   | 3.599 | 4.0            | 3.5         | **3.50**      |
#
# La hoja que Yusef mandó el 2026-08-12 escribe esos dos valores a mano, así que
# la buena era la del volumétrico. `PR-C7.11` dejó una sola implementación y
# **este barrido ahora va en milésimas**, que es donde el bug vivía.
class RedondeoMediaLibraCoincideTest < ActiveSupport::TestCase
  test "las dos entradas dan lo mismo en todo el rango util, al tercer decimal" do
    tarifa = Tarifa.new(incremento_libras: 0.5)
    discrepancias = []

    # De 0.000 a 40.000 en pasos de 0.001. El paso de 0.01 anterior es
    # exactamente lo que dejó pasar el bug durante meses.
    (0..40_000).each do |milesimas|
      peso = BigDecimal(milesimas) / 1000
      por_tarifa = tarifa.peso_facturable(peso).to_f
      por_volumetrico = VolumetricoCalculator.half_pound_round(peso.to_f)

      discrepancias << [ peso.to_f, por_tarifa, por_volumetrico ] if por_tarifa != por_volumetrico
    end

    assert_empty discrepancias.first(10),
                 "#{discrepancias.size} pesos donde las dos reglas no coinciden " \
                 "(peso, tarifa, volumétrico): #{discrepancias.first(10).inspect}"
  end

  # Los valores que Yusef escribió a mano en su hoja del 2026-08-12, uno por uno.
  # Si el barrido de arriba se rompiera por otra razón, estos dicen cuál umbral
  # se movió.
  #
  #   PESO REAL 5 lb · 648 pulg³ ÷ 166 = 3.90 VLbs → "ES IGUAL A 4"
  #   3.099 "es igual" 3 · 3.10 "es igual a" 3.50 · 3.599 "es igual" 3.50
  HOJA_DE_YUSEF = {
    "3.099" => 3.0,   # < .10 baja, aunque restarle 0.09 daría 3.009
    "3.10"  => 3.5,   # el umbral exacto de abajo
    "3.599" => 3.5,   # < .60 se queda en media
    "3.90"  => 4.0    # ≥ .60 sube
  }.freeze

  # Los cuatro que dictó en el audio del 2026-08-08, más su versión al tercer
  # decimal: 1.099 tiene que seguir siendo 1, igual que 1.09.
  AUDIO_2026_08_08 = {
    "1.09"  => 1.0,
    "1.099" => 1.0,
    "1.10"  => 1.5,
    "1.59"  => 1.5,
    "1.599" => 1.5,
    "1.60"  => 2.0
  }.freeze

  test "la hoja de Yusef, valor por valor" do
    verificar HOJA_DE_YUSEF
  end

  test "el audio del 2026-08-08, valor por valor" do
    verificar AUDIO_2026_08_08
  end

  # `Tarifa` delega en `VolumetricoCalculator`; este test fija que siga siendo
  # así. Si alguien le vuelve a escribir su propia aritmética, se entera acá y no
  # en una factura.
  test "tarifa devuelve BigDecimal, que es lo que multiplica al precio" do
    peso = Tarifa.new(incremento_libras: 0.5).peso_facturable(BigDecimal("3.10"))

    assert_kind_of BigDecimal, peso,
                   "el peso facturable multiplica un precio: un Float le mete ruido a la factura"
    assert_equal BigDecimal("3.5"), peso
  end

  private

  def verificar(casos)
    tarifa = Tarifa.new(incremento_libras: 0.5)

    casos.each do |peso, esperado|
      assert_equal esperado, tarifa.peso_facturable(BigDecimal(peso)).to_f, "Tarifa falló en #{peso}"
      assert_equal esperado, VolumetricoCalculator.half_pound_round(peso.to_f), "Volumétrico falló en #{peso}"
    end
  end
end
