require "bigdecimal"

# Convierte UNA sola medida (alto × largo × ancho, en pulgadas) a las tres
# representaciones que el operario ve en /etiquetar. Es la fuente de verdad
# (testeada) de las reglas de redondeo; el controller Stimulus
# `calc_volumetrico` replica la misma aritmética para feedback en vivo.
#
# Reglas confirmadas (spreadsheet de Yusef, 2026-06):
#   (A) USA→HN por libra o volumen ("la más común"):
#         VLbs = pulgadas³ / 166, redondeado a ½ libra con umbrales .10/.60
#         peso a cobrar = max(peso real, VLbs)
#   (B) USA→HN por pie cúbico (informativo, NO afluye en precio):
#         pies³ = pulgadas³ / 1728, SIEMPRE hacia arriba (ceil a entero)
#   (C) China→HN por metro cúbico (informativo, NO afluye en precio):
#         m³ = pulgadas³ × 16.387064 / 1_000_000, ceil a 2 decimales
module VolumetricoCalculator
  module_function

  DIVISOR_LB  = 166.0        # pulgadas³ → libra volumétrica (carga aérea)
  IN3_PER_FT3 = 1728.0       # pulgadas³ → pie³
  CM3_PER_IN3 = 16.387064    # 1 pulgada³ = 16.387064 cm³
  CM3_PER_M3  = 1_000_000.0  # 1 m³ = 1_000_000 cm³

  # Volumen en pulgadas³ a partir de dimensiones (pulgadas).
  def pulgadas_cubicas(alto, largo, ancho)
    return 0.0 unless alto && largo && ancho

    alto.to_f * largo.to_f * ancho.to_f
  end

  # (A) Libra volumétrica redondeada a ½ libra.
  def vlbs(in3)
    half_pound_round(in3.to_f / DIVISOR_LB)
  end

  # Redondeo a ½ libra con umbrales en .10 y .60 sobre la parte fraccionaria.
  #   frac < .10        → baja al entero
  #   .10 ≤ frac < .60  → .50
  #   frac ≥ .60        → sube al siguiente entero
  # Se trabaja en milésimas (enteros) para evitar el ruido de punto flotante
  # (p.ej. 4.1 - 4 = 0.0999… en float rompería el umbral .10).
  def half_pound_round(x)
    milesimas = (x.to_f * 1000).round
    entero    = milesimas / 1000
    frac      = milesimas % 1000

    if frac < 100
      entero.to_f
    elsif frac < 600
      entero + 0.5
    else
      entero + 1.0
    end
  end

  # Peso a cobrar (lo más común): el mayor entre peso real y VLbs.
  def peso_a_cobrar(peso_real, in3)
    [ peso_real.to_f, vlbs(in3) ].max
  end

  # (B) Pies cúbicos, SIEMPRE redondeado hacia arriba a entero.
  def pies_cubicos(in3)
    (in3.to_f / IN3_PER_FT3).round(6).ceil
  end

  # (C) Metros cúbicos, ceil a 2 decimales.
  def metros_cubicos(in3)
    ceil_to_2(in3.to_f * CM3_PER_IN3 / CM3_PER_M3)
  end

  # Ceil a 2 decimales vía BigDecimal para evitar que 2.94 → 2.95 por ruido
  # de float (2.94 * 100 = 294.00000000000006 en punto flotante).
  def ceil_to_2(x)
    (BigDecimal(x.to_f.to_s) * 100).ceil / 100.0
  end
end
