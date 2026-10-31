# C26-03 · «Unir»: el grupo de cajas que tienen que salir juntas, visto desde
# una que el operario acaba de escanear.
#
# Yusef: *"lo que ellos necesitan saber es si está consolidando el cliente,
# para no trabajar doble"*. Jorge, corrigiendo la primera versión: *"si vienen
# 3 warehouse receipts y en la pre-alerta vienen 3, se tienen que unir… lo
# ideal es que estén los 3, y luego se midan y pesen los 3 y salgan las 3
# stickers"*.
#
# ── Cajas, no renglones ───────────────────────────────────────────────────
#
# La primera versión contaba renglones de la pre-alerta. Un tracking que Miami
# partió en tres cajas contaba como **uno**, y son **tres stickers**. Acá se
# cuenta lo que el operario tiene en la mano: cada caja con su warehouse
# receipt.
#
# ── Los cuatro estados salen de la base, no se inventan ───────────────────
#
# Un paquete **recibe su número de recepción en el instante en que Miami lo
# ingresa** (`Paquete#debe_generar_numero_recepcion?`: mientras el estado es
# `pre_alerta_estado` no se genera). Y cada tracking que el cliente declara ya
# tiene su paquete «esperado» desde que escribió la pre-alerta
# (`PreAlertaPaquete#crear_paquete_esperado`). Así que:
#
#   sin warehouse receipt ......... el cliente lo declaró, Miami no lo tiene
#   con WR, fuera de Honduras ..... Miami lo ingresó, viene en camino
#   en Honduras, sin `medido_at` .. está acá, falta medirlo
#   con `medido_at` ............... medido
#
# No hace falta ninguna columna nueva: la grilla es una lectura.
class GrupoDeUnion
  # Estados con los que una caja ya no se espera en la mesa de medición.
  FUERA_DE_JUEGO = %w[facturado en_reparto entregado anulado retornado desechado].freeze

  # C34-07 · En qué orden se dice lo que falta: primero lo que está acá.
  ORDEN_DE_LO_QUE_FALTA = %w[aqui en_camino esperada].freeze

  # Una caja del grupo — un cuadrito de la pantalla.
  Caja = Struct.new(:paquete, :tracking, :descripcion, keyword_init: true) do
    def estado
      return "esperada" if paquete.nil? || paquete.numero_recepcion.blank?
      return "medida"   if paquete.medido_at.present?
      return "aqui"     if paquete.estado.in?(PreAlerta::ESTADOS_EN_HONDURAS)

      "en_camino"
    end

    def medida? = estado == "medida"
    def aqui?   = estado == "aqui"

    # C28-13 · ¿Esta caja, si falta en la tanda, **frena** el guardado?
    #
    # Yusef, el 2026-10-03: *"el sistema lo va a dejar pesar porque en el
    # manifiesto este no venían más, pero si viene y venían más paquetes no lo
    # debería dejar"*. O sea, la diferencia es entre «no vino» y «vino y no
    # aparece»:
    #
    #   · ya se recibió en Honduras y no está medida — está en algún estante;
    #   · o viajó en el mismo manifiesto que las cajas de la mesa — tendría que
    #     haber llegado con ellas.
    #
    # Lo que no vino —sigue en Miami, o viene en otro manifiesto— no frena: es
    # el «Facturar lo que hay» de siempre. Y lo que ya no está en juego (sacado
    # de la lista, en una pre-factura, entregado) tampoco.
    def bloquea_si_falta?(manifiesto_ids)
      return false if paquete.nil? || medida?
      return false if paquete.medicion_descartada_at.present?
      return false if paquete.pre_factura_id.present? || paquete.venta_id.present?
      return true if paquete.esperando_medicion?
      return false if paquete.estado.in?(FUERA_DE_JUEGO)

      paquete.manifiesto_id.present? && manifiesto_ids.include?(paquete.manifiesto_id)
    end

    # Para la lista del modal rojo: dónde está lo que falta.
    def donde
      { "esperada"  => "no ha llegado a Miami",
        "en_camino" => "en Miami, todavía no llega acá",
        "aqui"      => "acá, sin medir",
        "medida"    => "medida" }[estado]
    end
  end

  attr_reader :pre_alerta, :cajas, :manifiesto

  # El grupo de esta caja, o nil si va sola.
  #
  # Primero la pre-alerta **consolidada** del cliente que la lista, por vínculo
  # o por tracking. Si no hay, un tracking que Miami partió en varias cajas
  # también es un grupo: son varias stickers que salen juntas, aunque el
  # cliente no haya pedido consolidar.
  def self.de(paquete)
    pa = pre_alerta_consolidada_de(paquete)
    return new(pre_alerta: pa) if pa

    # Un envío partido también es un grupo: varias stickers que salen juntas,
    # aunque el cliente no haya pedido consolidar. Se arma por **warehouse
    # receipt** y no por `dividido?`: así no depende de que `cantidad_paquetes`
    # esté puesto, y no barre cajas de otro envío que reusó el tracking.
    cajas = paquete.cajas_del_mismo_envio.to_a
    return new(paquetes: cajas) if cajas.size > 1

    nil
  end

  # C29-16 · **Los paquetes del cliente que vinieron en el mismo manifiesto.**
  #
  # Escaneando a Diego, la pantalla dijo «Completado» con dos cajas, y Yusef:
  #
  #   > "Me dice completado, yo tengo más paquetes de Diego en el mismo
  #   >  manifiesto… no, no, no, por pre-alerta o sin pre-alerta, aquí no es
  #   >  por pre-alerta."
  #   > "Le diga: hey, Diego tiene cinco paquetes en el vuelo y solo estás
  #   >  escaneando tres, y faltan dos en el mismo manifiesto."
  #
  # Con una excepción, la del consolidado: *"al menos que el cliente tenga un
  # consolidado… ahí ya no le va a exigir que los mida juntos"*. Por eso salen
  # solo los **sueltos**: lo que está en una pre-alerta consolidada va con su
  # consolidado, que tiene su propia cuenta (`.de`).
  #
  # Y solo los del mismo servicio: los de otro no pueden entrar a esta tanda
  # («NO Mezclar», `PuedenIrJuntas`), así que contarlos dejaría el
  # «Completado» imposible. Lo que ya no está en juego —sacado de la lista,
  # anulado, entregado— no se espera; lo medido cuenta como resuelto.
  #
  # Se suman las cajas del envío de esta caja aunque viajen en otro
  # manifiesto: un split partido entre dos vuelos se seguía viendo entero, y
  # se sigue viendo.
  #
  # Es una **cuenta**, no un bloqueo: Yusef lo pidió como algo que *"le tiene
  # que decir"*, y las cajas de un envío que vinieron y no están ya frenan el
  # guardado con PIN (`C28-13`, `FaltantesDeLaTanda`). `nil` si el cliente no
  # tiene otro paquete suelto en ese manifiesto.
  def self.del_cliente_en_manifiesto(paquete)
    return nil if paquete.manifiesto_id.nil? || paquete.cliente_id.nil?

    candidatos = Paquete.where(manifiesto_id: paquete.manifiesto_id, cliente_id: paquete.cliente_id,
                               tipo_envio_id: paquete.tipo_envio_id, medicion_descartada_at: nil)
                        .where.not(estado: Paquete::NO_SON_CAJAS + %w[anulado retornado desechado])
                        .to_a
    candidatos |= paquete.cajas_del_mismo_envio.to_a
    sueltos = candidatos.reject { |p| p.id != paquete.id && pre_alerta_consolidada_de(p) }
                        .reject { |p| p.medido_at.blank? && (p.pre_factura_id || p.venta_id || p.estado.in?(FUERA_DE_JUEGO)) }
                        .sort_by { |p| [ p.numero_recepcion.to_s, p.numero_caja.to_i, p.id ] }
    return nil if sueltos.size <= 1

    new(paquetes: sueltos, manifiesto: paquete.manifiesto)
  end

  def self.pre_alerta_consolidada_de(paquete)
    return nil if paquete.cliente_id.nil?

    PreAlertaPaquete.joins(:pre_alerta)
                    .merge(PreAlerta.activas.where(consolidado: true, cliente_id: paquete.cliente_id))
                    .where("pre_alerta_paquetes.paquete_id = :id OR UPPER(pre_alerta_paquetes.tracking) = :t",
                           id: paquete.id, t: paquete.tracking.to_s.upcase)
                    .order(Arel.sql("pre_alertas.finalizado ASC, pre_alertas.created_at DESC"))
                    .first&.pre_alerta
  end

  def initialize(pre_alerta: nil, paquetes: nil, manifiesto: nil)
    @pre_alerta = pre_alerta
    @manifiesto = manifiesto
    @cajas = pre_alerta ? cajas_de(pre_alerta) : cajas_sueltas(paquetes)
  end

  def total    = cajas.size
  def medidas  = cajas.count(&:medida?)
  def aqui     = cajas.count(&:aqui?)
  def llegadas = cajas.count { |c| c.medida? || c.aqui? }

  # Lo que le falta al grupo para salir junto — lo que lista el modal rojo.
  def faltantes = cajas.reject(&:medida?)

  def completo? = total.positive? && medidas == total
  def consolidada? = pre_alerta&.consolidado? || false
  def cerrada? = pre_alerta.present? && (pre_alerta.finalizado? || pre_alerta.facturado?)
  def parcial_autorizado? = pre_alerta&.union_parcial_at.present?

  # Las que tienen algo que rotular. Una caja sin medir no lleva sticker.
  def paquetes_medidos = cajas.select(&:medida?).map(&:paquete)

  # C34-07 · Cómo se llama el grupo en un aviso: el consolidado por su
  # pre-alerta, el split por su warehouse receipt.
  def nombre
    return "El consolidado #{pre_alerta.numero_documento}" if pre_alerta

    wr = cajas.filter_map { |c| c.paquete&.numero_recepcion }.first
    wr ? "El envío #{wr}, que viene partido," : "El envío partido"
  end

  # Para que nadie lo forme a mano.
  def clave = pre_alerta ? "pa-#{pre_alerta.id}" : "wr-#{cajas.filter_map { |c| c.paquete&.id }.min}"

  # C34-07 · Lo que le falta al grupo, **escrito**: Yusef, en la pasada, *"6 de
  # 6, falta uno, pero debería decir falta uno que no ha llegado a Miami… es más
  # explícito"*.
  #
  # `en_pantalla`: las sesiones que la pantalla ya tiene cargadas. Lo medido en
  # **otra** tanda que nadie pre-facturó está en un estante: *"si ya tiene
  # agrupado, el sistema le dice que tiene que ir a traer los estantes"*.
  def lo_que_falta(en_pantalla: [])
    partes = faltantes.group_by(&:estado).sort_by { |estado, _| ORDEN_DE_LO_QUE_FALTA.index(estado) || 9 }
                      .map { |estado, lista| falta_texto(estado, lista.size) }
    en_estante = cajas.count do |c|
      c.medida? && c.paquete.pre_factura_id.nil? && c.paquete.venta_id.nil? &&
        !Array(en_pantalla).map(&:to_s).include?(c.paquete.medicion_sesion.to_s)
    end
    if en_estante.positive?
      partes << "#{en_estante} #{en_estante == 1 ? 'medido' : 'medidos'} en otra tanda: " \
                "#{en_estante == 1 ? 'traelo' : 'traelos'} del estante"
    end
    partes.to_sentence(two_words_connector: " y ", last_word_connector: " y ")
  end


  private

  def falta_texto(estado, n)
    verbo = n == 1 ? "falta 1" : "faltan #{n}"
    case estado
    when "esperada"  then "#{verbo} que no #{n == 1 ? 'ha' : 'han'} llegado a Miami"
    when "en_camino" then "#{verbo} en Miami, que todavía no #{n == 1 ? 'llega' : 'llegan'} acá"
    else                  "#{verbo} acá, sin medir"
    end
  end

  def cajas_de(pre_alerta)
    pre_alerta.pre_alerta_paquetes.includes(:paquete).order(:id).flat_map do |renglon|
      p = renglon.paquete
      next [ Caja.new(paquete: nil, tracking: renglon.tracking, descripcion: renglon.descripcion) ] if p.nil?

      hermanas(p).map do |c|
        Caja.new(paquete: c, tracking: renglon.tracking,
                 descripcion: renglon.descripcion.presence || c.descripcion)
      end
    end
  end

  def cajas_sueltas(paquetes)
    Array(paquetes).compact.uniq
                   .map { |c| Caja.new(paquete: c, tracking: c.tracking, descripcion: c.descripcion) }
  end

  # Las cajas del envío de este renglón. Un paquete «esperado» no tiene
  # warehouse receipt todavía, así que es un solo cuadrito — como debe.
  def hermanas(paquete)
    cajas = paquete.cajas_del_mismo_envio.to_a
    cajas.size > 1 ? cajas : [ paquete ]
  end
end
