# C26-02 · Pesar y medir una caja en San Pedro.
#
# Escribe los cuatro números y **sella** quién y cuándo. Lo demás ya lo hace el
# paquete solo: `calculate_peso_volumetrico` y `calculate_peso_cobrar` son
# `before_save`, así que VLBS y peso a cobrar quedan al día sin que esto los
# toque. No es un callback de `Paquete` porque /etiquetar también escribe
# `peso` desde Miami, y eso no es una medición de Honduras.
#
# **Se re-sella en cada medición** (la regla de `recibido_hn_por`): el sello
# responde «quién puso el dato que está», y en la línea se vuelve a pesar —
# Yusef: *"ya es la tercera vez que los pesamos"*.
class MedirPaquete
  class NoSePuede < StandardError; end

  CAMPOS = %i[peso alto largo ancho].freeze

  def initialize(paquete, user:)
    @paquete = paquete
    @user = user
  end

  def medir!(valores)
    numeros = CAMPOS.to_h { |c| [ c, Float(valores[c].to_s.tr(",", "."), exception: false) ] }
    faltan = numeros.select { |_c, v| v.nil? || v <= 0 }.keys
    raise NoSePuede, "Faltan #{faltan.join(', ')}: los cuatro tienen que ser mayores que cero." if faltan.any?
    raise NoSePuede, en_pre_factura_msg if @paquete.pre_factura_id.present? || @paquete.venta_id.present?
    raise NoSePuede, no_recibida_msg unless @paquete.estado.in?(Paquete::ESTADOS_FACTURABLES)

    @paquete.update!(**numeros, medido_at: Time.current, medido_por: @user&.iniciales_display)
    @paquete
  end

  private

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
