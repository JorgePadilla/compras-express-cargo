require "test_helper"

class VolumetricoCalculatorTest < ActiveSupport::TestCase
  # ── (A) VLbs: redondeo a ½ libra, umbrales .10/.60 ──
  # Ejemplos exactos del spreadsheet de Yusef.
  test "half_pound_round respeta los umbrales .10 y .60" do
    assert_equal 4.0,  VolumetricoCalculator.half_pound_round(3.90),  "≥ .60 sube"
    assert_equal 3.0,  VolumetricoCalculator.half_pound_round(3.099), "< .10 baja"
    assert_equal 3.5,  VolumetricoCalculator.half_pound_round(3.10),  ".10 → .50"
    assert_equal 3.5,  VolumetricoCalculator.half_pound_round(3.599), "< .60 → .50"
  end

  # PR-C7.11: `redondear_media_libra` es ahora la **única** implementación de la
  # regla —`Tarifa#redondear_al_incremento` delega acá— y por eso devuelve
  # BigDecimal: en el camino de la tarifa el resultado multiplica un precio, y un
  # Float le mete ruido a la factura. `half_pound_round` es el adaptador para el
  # camino de pantalla, que trabaja en Float de punta a punta.
  test "redondear_media_libra devuelve BigDecimal y no pierde exactitud" do
    r = VolumetricoCalculator.redondear_media_libra(BigDecimal("3.10"))

    assert_kind_of BigDecimal, r
    assert_equal BigDecimal("3.5"), r
  end

  test "redondear_media_libra da lo mismo entre en BigDecimal, Float o String" do
    %w[3.099 3.10 3.599 3.90].each do |s|
      esperado = VolumetricoCalculator.redondear_media_libra(BigDecimal(s))

      assert_equal esperado, VolumetricoCalculator.redondear_media_libra(s.to_f), "float #{s}"
      assert_equal esperado, VolumetricoCalculator.redondear_media_libra(s),      "string #{s}"
    end
  end

  test "half_pound_round es robusto al ruido de float" do
    # 4.1 - 4 = 0.0999999… en float; en milésimas cae limpio en .10 → .50
    assert_equal 4.5, VolumetricoCalculator.half_pound_round(4.1)
    assert_equal 2.0, VolumetricoCalculator.half_pound_round(2.0)
    assert_equal 2.5, VolumetricoCalculator.half_pound_round(2.55), "< .60 → .50"
    assert_equal 3.0, VolumetricoCalculator.half_pound_round(2.60), ".60 exacto sube"
  end

  test "vlbs divide entre 166 y redondea" do
    # 648 in³ / 166 = 3.9036 → 4.0
    assert_equal 4.0, VolumetricoCalculator.vlbs(648)
  end

  test "peso_a_cobrar toma el mayor entre peso real y VLbs" do
    # in3 chico → VLbs bajo, gana el peso real
    assert_equal 10.0, VolumetricoCalculator.peso_a_cobrar(10.0, 166)
    # in3 grande → VLbs gana
    assert_equal 4.0,  VolumetricoCalculator.peso_a_cobrar(1.0, 648)
  end

  # ── (B) Pies cúbicos: ceil a entero ──
  test "pies_cubicos siempre redondea hacia arriba" do
    # 179424 in³ / 1728 = 103.83 → 104
    assert_equal 104, VolumetricoCalculator.pies_cubicos(179_424)
    # múltiplo exacto no se infla
    assert_equal 2, VolumetricoCalculator.pies_cubicos(3456)
    assert_equal 1, VolumetricoCalculator.pies_cubicos(1)
  end

  # ── (C) Metros cúbicos: ceil a 2 decimales ──
  test "ceil_to_2 redondea hacia arriba al segundo decimal" do
    assert_equal 2.95, VolumetricoCalculator.ceil_to_2(2.9402)
    assert_equal 2.94, VolumetricoCalculator.ceil_to_2(2.9400)
    assert_equal 2.94, VolumetricoCalculator.ceil_to_2(2.9301)
    assert_equal 2.95, VolumetricoCalculator.ceil_to_2(2.9401)
  end

  test "metros_cubicos convierte pulgadas³ a m³ con ceil-2" do
    # 179424 in³ → 2.9402 m³ → 2.95
    assert_equal 2.95, VolumetricoCalculator.metros_cubicos(179_424)
  end

  test "pulgadas_cubicas multiplica las tres dimensiones" do
    assert_equal 648.0, VolumetricoCalculator.pulgadas_cubicas(8, 9, 9)
    assert_equal 0.0,   VolumetricoCalculator.pulgadas_cubicas(nil, 9, 9)
  end
end
