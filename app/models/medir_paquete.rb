# C26-02 · Pesar y medir una caja en San Pedro.
#
# Escribe los números que el operario haya puesto y **sella** quién y cuándo. Lo
# demás ya lo hace el paquete solo: `calculate_peso_volumetrico` y
# `calculate_peso_cobrar` son `before_save`, así que VLBS y peso a cobrar quedan
# al día sin que esto los toque. No es un callback de `Paquete` porque
# /etiquetar también escribe `peso` desde Miami, y eso no es una medición de
# Honduras.
#
# **Se re-sella en cada medición** (la regla de `recibido_hn_por`): el sello
# responde «quién puso el dato que está», y en la línea se vuelve a pesar —
# Yusef: *"ya es la tercera vez que los pesamos"*.
#
# ── No hacen falta los cuatro ──────────────────────────────────────────────
#
# La primera versión exigía los cuatro mayores que cero, y con eso **una caja
# chiquita no se podía medir**. Yusef, el 2026-09-07:
#
#   "Siempre vas a meter length, height, width y weight. A veces no se mide,
#    cuando es una cajita bien pequeñita. Pero **siempre una de estas cuatro se
#    mete** —que sería peso en ese caso—, o estas tres, o esta, o todo, **para
#    que el sistema diga cuál es el mayor**."
#
# Así que la regla es: **al menos uno**. Las tres dimensiones van juntas o no
# van —un volumétrico con dos de tres no existe—, y lo que se deja en blanco
# **no se toca**: si Miami ya había digitado medidas, siguen ahí y el
# volumétrico las sigue usando. Quien decide cuál manda es
# `VolumetricoCalculator.entre_peso_y_vlbs`, que ya elige el mayor.
class MedirPaquete
  class NoSePuede < StandardError; end

  CAMPOS = %i[peso alto largo ancho].freeze
  DIMENSIONES = %i[alto largo ancho].freeze

  def initialize(paquete, user:)
    @paquete = paquete
    @user = user
  end

  def medir!(valores)
    numeros = self.class.numeros_de(valores)
    raise NoSePuede, sin_nada_msg if numeros.empty?
    raise NoSePuede, dimensiones_a_medias_msg if dimensiones_a_medias?(numeros)
    raise NoSePuede, en_pre_factura_msg if @paquete.pre_factura_id.present? || @paquete.venta_id.present?
    raise NoSePuede, no_recibida_msg unless @paquete.estado.in?(Paquete::ESTADOS_FACTURABLES)

    @paquete.update!(**numeros, medido_at: Time.current, medido_por: @user&.iniciales_display)
    @paquete
  end

  # Los que vienen con un número **positivo**. Un campo en blanco, en cero o con
  # basura no es un dato: se cae de la lista y el paquete se queda con lo que
  # tenía.
  def self.numeros_de(valores)
    CAMPOS.filter_map do |campo|
      valor = Float(valores[campo].to_s.tr(",", "."), exception: false)
      [ campo, valor ] if valor&.positive?
    end.to_h
  end

  private

  def dimensiones_a_medias?(numeros)
    puestas = DIMENSIONES.count { |d| numeros.key?(d) }
    puestas.positive? && puestas < DIMENSIONES.size
  end

  def sin_nada_msg
    "#{codigo}: poné al menos el peso, o las tres medidas. Todo en blanco no es una medición."
  end

  def dimensiones_a_medias_msg
    "#{codigo}: las medidas van las tres —alto, largo y ancho— o ninguna. " \
      "Con dos de tres no hay volumétrico."
  end

  def en_pre_factura_msg
    "#{codigo} ya está en una pre-factura: el peso se congeló ahí. No se mide desde acá."
  end

  def no_recibida_msg
    "#{codigo} está «#{@paquete.estado.to_s.humanize}»: todavía no se recibió. Pasala por Recibir Carga."
  end

  def codigo
    @paquete.numero_recepcion_visible.presence || @paquete.tracking
  end
end
