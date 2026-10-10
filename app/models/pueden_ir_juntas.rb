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
#
# PR-P.11a · Desde que la pre-factura sale **solo** escaneando (Jorge,
# 2026-10-10: quitar la de a mano), lo que la puerta a mano resolvía se frena
# acá, en la mesa, que es donde todavía se puede separar:
#
# - `otra_sucursal` — **en todos lados**: la pre-factura es de una sucursal de
#   retiro (su etiqueta de entrega va pegada en una bolsa), y la tarifa puede
#   cambiar por sucursal.
# - `prepago_mezclado`, `otra_tarifa`, `otro_trato_de_cobro` — **solo dentro de
#   una tanda** (`misma_tanda: true`, Medición): son reglas del **volumen**, que
#   se cobra con una sola tarifa y un solo trato. Dos tandas distintas sí van
#   en la misma pre-factura —cada volumen es su línea—, así que Auditar y F9 no
#   las preguntan.
class PuedenIrJuntas
  Problema = Struct.new(:motivo, :mensaje, :pre_alerta, keyword_init: true)

  # Los motivos que solo valen dentro de una tanda de Medición.
  SOLO_DE_TANDA = %w[prepago_mezclado otra_tarifa otro_trato_de_cobro].freeze

  def initialize(ya_escaneadas, candidata, misma_tanda: false)
    @ya = Array(ya_escaneadas).compact
    @nueva = candidata
    @misma_tanda = misma_tanda
  end

  def problema
    return nil if @ya.empty? || @nueva.nil?
    return repetida if @ya.any? { |p| p.id == @nueva.id }
    return otro_cliente if @ya.first.cliente_id != @nueva.cliente_id
    return otro_servicio if @ya.first.tipo_envio_id != @nueva.tipo_envio_id
    return otra_sucursal if @ya.first.sucursal_id != @nueva.sucursal_id

    # La consolidación va antes que las reglas del volumen: su modal tiene
    # salidas («unir», «hago el consolidado») que las otras no.
    consolidacion = otra_consolidacion
    return consolidacion if consolidacion
    return nil unless @misma_tanda

    prepago_mezclado || otra_tarifa || otro_trato_de_cobro
  end

  # La consolidación de un paquete, o nil si va suelto.
  def self.consolidacion_de(paquete)
    GrupoDeUnion.pre_alerta_consolidada_de(paquete)
  end

  private

  def repetida
    Problema.new(motivo: "repetida",
                 mensaje: "#{codigo(@nueva)} ya la escaneaste: no la escanees dos veces.")
  end

  # Yusef: *"escanea uno de Jorge y va y escanea otro y ese no es el mismo Jorge
  # —en vez de Jorge Padilla es Jorge Manzano—: le tira error, es diferente
  # cliente"*. Las salidas que él mismo pidió —quitar el último o empezar de
  # nuevo— las ofrece el modal.
  def otro_cliente
    Problema.new(motivo: "otro_cliente",
                 mensaje: "#{codigo(@nueva)} es de #{nombre(@nueva)}, y lo que ya escaneaste " \
                          "es de #{nombre(@ya.first)}. No se miden juntos.")
  end

  def otro_servicio
    Problema.new(motivo: "otro_servicio",
                 mensaje: "#{codigo(@nueva)} va por #{@nueva.tipo_envio&.nombre}, y lo que ya escaneaste " \
                          "va por #{@ya.first.tipo_envio&.nombre}. Cada servicio se factura aparte.")
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
    elsif UnirAlConsolidado.se_puede?(@nueva, de_la_mesa)
      # C29-17 · La suelta **sin ninguna pre-alerta**, del mismo cliente, con
      # un consolidado en la mesa: no es un error, es una pregunta. Yusef:
      # *"¿desea agregar este paquete a esta consolidación?"* — *"que el mismo
      # que está pesando y midiendo los agrega"*. Hasta que la agreguen sigue
      # sin poder entrar: se facturaría aparte de lo que se midió con ella.
      Problema.new(motivo: "unible", pre_alerta: de_la_mesa,
                   mensaje: "#{codigo(@nueva)} es de #{nombre(@nueva)} y no está en ninguna pre-alerta. " \
                            "Lo que ya escaneaste es del consolidado #{de_la_mesa.numero_documento}.")
    else
      Problema.new(motivo: "no_consolidada", pre_alerta: de_la_mesa,
                   mensaje: "#{codigo(@nueva)} no está consolidando, y lo que ya escaneaste es de " \
                            "la pre-alerta #{de_la_mesa.numero_documento}. Se facturan aparte.")
    end
  end

  # PR-P.11a · La sucursal donde **retira** el cliente (`paquetes.sucursal`).
  # Una sin sucursal contra una con sucursal también es distinta: la etiqueta
  # de entrega no sabría a cuál mandar la bolsa.
  def otra_sucursal
    Problema.new(motivo: "otra_sucursal",
                 mensaje: "#{codigo(@nueva)} se retira en #{sucursal_de(@nueva)}, y lo que ya escaneaste " \
                          "se retira en #{sucursal_de(@ya.first)}. Cada sucursal se factura aparte.")
  end

  # PR-P.11a · RP-89 · Una tanda prepagada en Miami se cobra con el simbólico
  # (`ArmarPreFacturaPorVolumen`); una que mezcla no tiene cómo cobrarse: el
  # volumen pesa las dos cosas juntas. Provisorio hasta que Yusef conteste si
  # Medición las rechaza o las separa sola (pregunta 2 de P.11).
  def prepago_mezclado
    return nil if @ya.first.prepagado_miami? == @nueva.prepagado_miami?

    Problema.new(motivo: "prepago_mezclado",
                 mensaje: "#{codigo(@nueva)} #{@nueva.prepagado_miami? ? 'viene' : 'no viene'} prepagada en Miami, " \
                          "y lo que ya escaneaste #{@ya.first.prepagado_miami? ? 'sí' : 'no'}. " \
                          "Las prepagadas se miden aparte.")
  end

  # PR-P.11a · RP-92 · Mismo cliente y servicio no garantiza la misma tarifa:
  # `Tarifa.resolver` también mira el proveedor y la sucursal. Se compara
  # **qué nivel aplicaría** (`Tarifa.clave`), que no depende del peso: el peso
  # del volumen todavía no existe. `ArmarPreFacturaPorVolumen#misma_tarifa!`
  # queda como la última red, ya con el peso.
  def otra_tarifa
    return nil if @ya.first.proveedor_id == @nueva.proveedor_id && @ya.first.sucursal_id == @nueva.sucursal_id
    return nil if clave_de(@ya.first) == clave_de(@nueva)

    Problema.new(motivo: "otra_tarifa",
                 mensaje: "#{codigo(@nueva)} se cobra con otra tarifa (proveedor #{@nueva.proveedor&.nombre || '—'}) " \
                          "que lo que ya escaneaste (#{@ya.first.proveedor&.nombre || '—'}). Se miden aparte.")
  end

  # PR-P.11a · RP-72 · La excepción de cobro de una caja («solo peso», «solo
  # volumétrico», `MarcarCobroExcepcion`) aplica al volumen solo si la llevan
  # todas (`Bulto#solo_peso?`): medida junto con otra se perdía en silencio.
  # Provisorio hasta que Yusef diga si es siempre aparte o solo un aviso.
  def otro_trato_de_cobro
    return nil if @ya.first.cobro_excepcion == @nueva.cobro_excepcion

    Problema.new(motivo: "otro_trato_de_cobro",
                 mensaje: "#{codigo(@nueva)} se cobra #{trato(@nueva)}, y lo que ya escaneaste " \
                          "se cobra #{trato(@ya.first)}. Con tratos distintos se miden aparte.")
  end

  def clave_de(paquete)
    Tarifa.clave(tipo_envio: paquete.tipo_envio, cliente: paquete.cliente,
                 proveedor: paquete.proveedor, sucursal: paquete.sucursal)
  end

  def trato(paquete)
    case paquete.cobro_excepcion
    when "solo_peso" then "solo por el peso real"
    when "solo_volumetrico" then "solo por el volumétrico"
    else "normal (el mayor de peso y volumen)"
    end
  end

  def sucursal_de(paquete) = paquete.sucursal&.nombre || "ninguna sucursal"

  def codigo(paquete)
    paquete.numero_recepcion_visible.presence || paquete.tracking
  end

  def nombre(paquete) = paquete.cliente&.nombre_completo
end
