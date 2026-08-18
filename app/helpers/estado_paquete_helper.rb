# Cómo se llama cada estado del paquete cuando alguien lo lee.
#
# A7-13/A7-14/A7-15, Conversación 7. Yusef insistió en esto contra la
# resistencia de Jorge a alargar la lista, y el argumento que lo cerró no fue de
# diseño sino una queja de un cliente real:
#
#   > "Un cliente me dijo: recibí un WhatsApp que ya tengo disponible el
#   >  producto, pero entro a la página web y me dice que todavía no, que sale
#   >  aduanas todavía. **¿Cuál es el estatus real?**"
#   > "Han ido a recogerlo a Tegucigalpa y no está ahí."
#
# Y cómo lo quiere: *"Disponible en sucursal Tegucigalpa. Disponible en sucursal
# SPS Cerón."* Lo llamó *"precontestarle la pregunta al cliente"*.
module EstadoPaqueteHelper
  # El rótulo genérico, sin paquete: para dropdowns y filtros.
  #
  # A7-14 vive acá. Yusef fue explícito con `enviado_sucursal`:
  #
  #   > **Jorge:** "¿En camino sería mejor?"
  #   > **Yusef:** "**No, enviado.** Porque *en camino* van a creer que ya va
  #   >  para ahí ahorita, y van a creer que es ahorita."
  ETIQUETAS = {
    "pre_alerta_estado"     => "Pre-alerta",
    "recibido_miami"        => "Recibido en Miami",
    "consolidando_miami"    => "Consolidando en Miami",
    "empacado"              => "Empacado",
    "enviado_honduras"      => "Enviado a Honduras",
    "en_aduana"             => "En aduana",
    "consolidando_honduras" => "Consolidando en Honduras",
    "disponible_entrega"    => "Disponible",
    "enviado_sucursal"      => "Enviado a sucursal",
    "pre_facturado"         => "Pre-facturado",
    "facturado"             => "Facturado",
    "en_reparto"            => "En reparto",
    "recoleta_en_proceso"   => "Recolecta en proceso",
    "entregado"             => "Entregado",
    "retenido"              => "Retenido",
    "retornado"             => "Retornado",
    "desechado"             => "Desechado",
    "anulado"               => "Anulado"
  }.freeze

  def estado_etiqueta(estado)
    ETIQUETAS[estado.to_s] || estado.to_s.humanize
  end

  # El rótulo con el paquete en la mano, que es el que ve el cliente. Le pega la
  # sucursal cuando la sucursal es justamente el dato que le falta.
  #
  # Si el paquete no tiene sucursal, cae al rótulo genérico en vez de inventar:
  # *"Disponible"* a secas es peor que decir la sucursal, pero mucho mejor que
  # decir una equivocada.
  def estado_de(paquete)
    base = estado_etiqueta(paquete.estado)

    case paquete.estado
    when "disponible_entrega"
      sucursal = paquete.sucursal&.nombre
      sucursal.present? ? "Disponible en sucursal #{sucursal}" : base
    when "enviado_sucursal"
      sucursal = (paquete.sucursal_destino || paquete.sucursal)&.nombre
      sucursal.present? ? "Enviado a sucursal #{sucursal}" : base
    when "entregado"
      # A7-15: *"el entregado sería bueno poner ahí las iniciales de la sucursal
      # donde se entregó… para que uno pueda entender en dónde se entregó."*
      # `Sucursal#codigo` ya son esas iniciales (MIA, SPS, TGU, SAM).
      codigo = paquete.sucursal&.codigo
      codigo.present? ? "#{base} (#{codigo})" : base
    else
      base
    end
  end

  # ── El mismo estado, para la tabla del operador ─────────────────────────
  #
  # Yusef, 2026-08-18, midiendo el ancho de `/paquetes` con el mouse: *"el
  # tracking necesitamos verlo completo… si no, vamos a tener que estar entrando
  # a cada tracking para poder encontrar uno"*. Y de dónde sacar el espacio lo
  # señaló él mismo: *"le puedes poner «rep Miami»… «hn», no pones Honduras sino
  # que «hn», cosas así"*.
  #
  # **No se toca `ETIQUETAS`.** Esos rótulos largos son los que ve el cliente y
  # los peleó él mismo en A7-13, contra la resistencia de Jorge a alargarlos:
  #
  #   > "Un cliente me dijo: recibí un WhatsApp que ya tengo disponible el
  #   >  producto, pero entro a la página y me dice que todavía no."
  #
  # Son dos audiencias distintas: el cliente necesita la frase entera, el
  # operario necesita el ancho. El largo sigue estando, en el `title`.
  CORTAS = {
    "pre_alerta_estado"     => "PRE-ALERTA",
    "recibido_miami"        => "REC MIAMI",
    "consolidando_miami"    => "CONS MIAMI",
    "empacado"              => "EMPACADO",
    "enviado_honduras"      => "ENVIADO HN",
    "en_aduana"             => "ADUANA",
    "consolidando_honduras" => "CONS HN",
    "disponible_entrega"    => "DISPONIBLE",
    "enviado_sucursal"      => "ENVIADO",
    "pre_facturado"         => "PRE-FACT",
    "facturado"             => "FACTURADO",
    "en_reparto"            => "REPARTO",
    "recoleta_en_proceso"   => "RECOLECTA",
    "entregado"             => "ENTREGADO",
    "retenido"              => "RETENIDO",
    "retornado"             => "RETORNADO",
    "desechado"             => "DESECHADO",
    "anulado"               => "ANULADO"
  }.freeze

  # Los tres estados donde la sucursal **es** el dato que falta se la llevan
  # pegada, con el código de tres letras que ya existe (`MIA`, `SPS`, `TGU`).
  # Es lo mismo que hace `estado_de`, pero en tres letras en vez de la frase.
  ESTADOS_CON_SUCURSAL = %w[disponible_entrega enviado_sucursal entregado].freeze

  def estado_corto(paquete)
    base = CORTAS[paquete.estado.to_s] || paquete.estado.to_s.upcase
    return base unless ESTADOS_CON_SUCURSAL.include?(paquete.estado.to_s)

    sucursal = paquete.estado == "enviado_sucursal" ? (paquete.sucursal_destino || paquete.sucursal) : paquete.sucursal
    codigo = sucursal&.codigo
    codigo.present? ? "#{base} #{codigo.upcase}" : base
  end
end
