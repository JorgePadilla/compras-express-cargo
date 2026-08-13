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
  #
  # **Esta es la única implementación de la regla.** `Tarifa#redondear_al_incremento`
  # delega acá cuando el incremento es media libra.
  #
  # Vivió duplicada hasta `PR-C7.11`: `Tarifa` la resolvía restando una tolerancia
  # de 0.09 y haciendo `ceil`. Las dos coinciden en todo peso de **dos** decimales
  # —por eso el barrido de `redondeo_media_libra_coincide_test` nunca las separó—
  # pero restar 0.09 no es lo mismo que "por debajo de .10", y en el tercer decimal
  # se iban:
  #
  #   | peso  | restando 0.09 | esta | hoja de Yusef |
  #   |-------|---------------|------|---------------|
  #   | 3.099 | 3.5           | 3.0  | **3**         |
  #   | 3.599 | 4.0           | 3.5  | **3.50**      |
  #
  # La hoja que Yusef mandó el 2026-08-12 escribe esos dos valores, así que la
  # buena es esta y la otra se fue.
  #
  # Se trabaja en milésimas (enteros) para evitar el ruido de punto flotante
  # (p.ej. 4.1 - 4 = 0.0999… en float rompería el umbral .10).
  #
  # Devuelve `BigDecimal` porque el resultado va a multiplicar un precio: en el
  # camino de `Tarifa` esto es plata, y meterle un Float a la factura le mete
  # ruido. `half_pound_round` es el adaptador para el camino de pantalla.
  def redondear_media_libra(peso)
    exacto       = peso.is_a?(BigDecimal) ? peso : BigDecimal(peso.to_s)
    milesimas    = (exacto * 1000).round
    entero, frac = milesimas.divmod(1000)

    if frac < 100
      BigDecimal(entero)
    elsif frac < 600
      entero + BigDecimal("0.5")
    else
      BigDecimal(entero + 1)
    end
  end

  # La misma regla, en Float. Es lo que consumen la calculadora de `/etiquetar` y
  # el resto del módulo, que trabajan en Float de punta a punta.
  def half_pound_round(x)
    redondear_media_libra(x.to_f).to_f
  end

  # Peso a cobrar (lo más común): el mayor entre peso real y VLbs.
  def peso_a_cobrar(peso_real, in3, solo_volumetrico: false)
    entre_peso_y_vlbs(peso_real.to_f, vlbs(in3), solo_volumetrico: solo_volumetrico)
  end

  # PR-C6.41 · RP-04b: la regla de qué peso manda, en un solo lugar.
  #
  # Antes vivía copiada en tres: `Paquete#calculate_peso_cobrar`,
  # `CotizadorFlete#peso_cobrar` y `peso_a_cobrar` acá (que solo llamaban los
  # tests). Es la misma duplicación entre pantallas gemelas que ya mordió cuatro
  # veces en este proyecto, y acá el precio de que se separen es que la
  # calculadora de /etiquetar le muestre al operario un peso distinto del que
  # factura la pre-factura.
  #
  # **Selecciona, no calcula**: devuelve uno de sus dos argumentos tal cual. El
  # peso a cobrar es plata y llega como BigDecimal; convertirlo a float acá le
  # metería ruido de punto flotante a la factura.
  #
  # `solo_volumetrico` es el trato de mayorista de Yusef. El guard de cero no es
  # cosmético: si el operario todavía no tecleó las medidas, el volumétrico es 0
  # y sin el guard el paquete se cobraría **gratis**.
  def entre_peso_y_vlbs(peso_real, vlbs, solo_volumetrico: false)
    return vlbs if solo_volumetrico && vlbs.to_f.positive?

    [ peso_real, vlbs ].max
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
