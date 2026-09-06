# C26-03 · «Unir»: el grupo de la pre-alerta consolidada, visto desde una caja.
#
# Yusef: *"lo que ellos necesitan saber es si está consolidando el cliente,
# para no trabajar doble"*. Jorge: *"al escanear le tiene que salir cuántos
# paquetes hacen falta para que se envíen todos con todas las medidas al mismo
# tiempo"*.
#
# Es una **consulta**, no un estado: cuántos renglones tiene la pre-alerta,
# cuántos llegaron a Honduras, cuántos están medidos, y cuáles faltan con su
# «dónde». Que el grupo esté listo se calcula cada vez que alguien pregunta.
class GrupoDeUnion
  Faltante = Struct.new(:tracking, :descripcion, :donde, keyword_init: true)

  attr_reader :pre_alerta, :total, :llegados, :medidos, :faltantes

  # La pre-alerta consolidada del cliente que lista esta caja, por vínculo o por
  # tracking (un renglón sin `paquete_id` todavía es un renglón que falta). Si
  # hay una abierta y una cerrada, la abierta manda.
  def self.de(paquete)
    return nil if paquete.cliente_id.nil?

    renglon = PreAlertaPaquete.joins(:pre_alerta)
                              .merge(PreAlerta.activas.where(consolidado: true, cliente_id: paquete.cliente_id))
                              .where("pre_alerta_paquetes.paquete_id = :id OR UPPER(pre_alerta_paquetes.tracking) = :t",
                                     id: paquete.id, t: paquete.tracking.to_s.upcase)
                              .order(Arel.sql("pre_alertas.finalizado ASC, pre_alertas.created_at DESC"))
                              .first
    renglon && new(renglon.pre_alerta)
  end

  def initialize(pre_alerta)
    @pre_alerta = pre_alerta
    renglones = pre_alerta.pre_alerta_paquetes.includes(:paquete).order(:id).to_a
    @total = renglones.size
    llegados = renglones.select { |r| llegado?(r) }
    @llegados = llegados.size
    @medidos = llegados.count { |r| r.paquete.medido_at.present? }
    @faltantes = renglones.reject { |r| llegado?(r) && r.paquete.medido_at.present? }.map do |r|
      Faltante.new(tracking: r.tracking, descripcion: r.descripcion,
                   donde: llegado?(r) ? "llegó, sin medir" : "no ha llegado")
    end
  end

  def completo? = @total.positive? && @medidos == @total
  def cerrada? = pre_alerta.finalizado? || pre_alerta.facturado?
  def parcial_autorizado? = pre_alerta.union_parcial_at.present?

  private

  # «Llegado» es un renglón con paquete en un estado de Honduras. Explícito y
  # no derivado de `PAQUETE_TO_PRE_ALERTA_ESTADO`, que no conoce
  # `consolidando_honduras` — justo el estado de unir.
  # El renglón **tiene** su paquete desde que se crea (`crear_paquete_esperado`,
  # en `pre_alerta_estado`), y Miami lo convierte en el real al recibirlo. Un
  # renglón cuyo paquete sigue antes de Honduras es un renglón que no llegó.
  def llegado?(renglon)
    renglon.paquete.present? && renglon.paquete.estado.in?(PreAlerta::ESTADOS_EN_HONDURAS)
  end
end
