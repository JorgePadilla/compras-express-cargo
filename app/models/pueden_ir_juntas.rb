# C26-19 · «NO Mezclar»: si estas cajas pueden ir en la misma medición.
#
# Está escrito en negro en la pizarra del 2026-09-07, y Yusef lo dijo con
# palabras dos veces. Primero la regla:
#
#   "Le tienen que decir si lo puede hacer o no lo puede hacer… **no lo podría
#    hacer porque está consolidando esa carga con otros paquetes**. Le debería
#    tirar un error, un modal que le diga: hey, no, ese está consolidando con
#    tal pre-alerta, con tal número. Ese va amarrado con otra."
#
# Y después de dónde sale, que es lo que la hace barata de construir:
#
#   "Es como los trackings cuando los escaneamos en Miami: escaneamos el
#    tracking uno y el tracking dos, **que valida que sean del mismo código de
#    cliente, mismo código de servicio**, etcétera. **Esa validación la vamos a
#    hacer acá.**"
#
# El porqué es de facturación, y Yusef fue a confirmarlo con Vanessa en la misma
# reunión: un cliente con dos paquetes consolidados y uno suelto lleva
# **facturas separadas** — *"nosotros facturamos de acuerdo a la pre-alerta"*.
# Meterlos en un bulto los cobraría juntos.
#
# Devuelve `nil` si pueden ir juntas, o un motivo con lo que hay que decirle al
# operario. No decide la UI: quién abre cuál modal es del controller.
class PuedenIrJuntas
  Problema = Struct.new(:motivo, :mensaje, :pre_alerta, keyword_init: true)

  def initialize(ya_escaneadas, candidata)
    @ya = Array(ya_escaneadas).compact
    @nueva = candidata
  end

  def problema
    return nil if @ya.empty? || @nueva.nil?
    return repetida if @ya.any? { |p| p.id == @nueva.id }
    return otro_cliente if @ya.first.cliente_id != @nueva.cliente_id
    return otro_servicio if @ya.first.tipo_envio_id != @nueva.tipo_envio_id

    otra_consolidacion
  end

  # La consolidación de un paquete, o nil si va suelto.
  def self.consolidacion_de(paquete)
    GrupoDeUnion.pre_alerta_consolidada_de(paquete)
  end

  private

  def repetida
    Problema.new(motivo: "repetida",
                 mensaje: "#{codigo(@nueva)} ya está en la mesa: no lo escanees dos veces.")
  end

  # Yusef: *"escanea uno de Jorge y va y escanea otro y ese no es el mismo Jorge
  # —en vez de Jorge Padilla es Jorge Manzano—: le tira error, es diferente
  # cliente"*. Las salidas que él mismo pidió —quitar el último o empezar de
  # nuevo— las ofrece el modal.
  def otro_cliente
    Problema.new(motivo: "otro_cliente",
                 mensaje: "#{codigo(@nueva)} es de #{nombre(@nueva)}, y en la mesa " \
                          "tenés a #{nombre(@ya.first)}. No se miden juntos.")
  end

  def otro_servicio
    Problema.new(motivo: "otro_servicio",
                 mensaje: "#{codigo(@nueva)} va por #{@nueva.tipo_envio&.nombre}, y en la mesa " \
                          "tenés #{@ya.first.tipo_envio&.nombre}. Cada servicio se factura aparte.")
  end

  # Las dos direcciones cuentan: entra una consolidada donde hay sueltas, o
  # entra una suelta donde hay un consolidado armado.
  def otra_consolidacion
    de_la_mesa = self.class.consolidacion_de(@ya.first)
    de_la_nueva = self.class.consolidacion_de(@nueva)
    return nil if de_la_mesa&.id == de_la_nueva&.id

    if de_la_nueva
      Problema.new(motivo: "otra_consolidacion", pre_alerta: de_la_nueva,
                   mensaje: "#{codigo(@nueva)} está consolidando con la pre-alerta " \
                            "#{de_la_nueva.numero_documento}. Ese va amarrado con otra: " \
                            "o hacés ese consolidado, o lo dejás de lado y terminás lo que tenés.")
    else
      Problema.new(motivo: "no_consolidada", pre_alerta: de_la_mesa,
                   mensaje: "#{codigo(@nueva)} no está consolidando, y en la mesa estás armando " \
                            "la pre-alerta #{de_la_mesa.numero_documento}. Se facturan aparte.")
    end
  end

  def codigo(paquete)
    paquete.numero_recepcion_visible.presence || paquete.tracking
  end

  def nombre(paquete) = paquete.cliente&.nombre_completo
end
