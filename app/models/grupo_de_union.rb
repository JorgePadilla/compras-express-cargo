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

    # Para la lista del modal rojo: dónde está lo que falta.
    def donde
      { "esperada"  => "no ha llegado a Miami",
        "en_camino" => "en Miami, todavía no llega acá",
        "aqui"      => "acá, sin medir",
        "medida"    => "medida" }[estado]
    end
  end

  attr_reader :pre_alerta, :cajas

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

  def self.pre_alerta_consolidada_de(paquete)
    return nil if paquete.cliente_id.nil?

    PreAlertaPaquete.joins(:pre_alerta)
                    .merge(PreAlerta.activas.where(consolidado: true, cliente_id: paquete.cliente_id))
                    .where("pre_alerta_paquetes.paquete_id = :id OR UPPER(pre_alerta_paquetes.tracking) = :t",
                           id: paquete.id, t: paquete.tracking.to_s.upcase)
                    .order(Arel.sql("pre_alertas.finalizado ASC, pre_alertas.created_at DESC"))
                    .first&.pre_alerta
  end

  def initialize(pre_alerta: nil, paquetes: nil)
    @pre_alerta = pre_alerta
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

  private

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
