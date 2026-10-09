# C29-17 · Unir una caja **suelta** al consolidado que se está midiendo.
#
# Con el consolidado de Sofía en la mesa, Jorge escaneó otra caja de Sofía que
# no estaba en ninguna pre-alerta, y Yusef, el 2026-10-08:
#
#   > "Éste que tengo acá debería de darte la opción de agregárselo a este
#   >  consolidado, porque ahora es uno y no tiene pre-alerta ni nada… está
#   >  independiente, y tal vez el que pidió la cliente que se lo uniera."
#   > "En vez de darle dolor de cabeza a alguien que empiece a agregarlos y a
#   >  moverlos, que el mismo que está pesando y midiendo los agrega."
#
# Y la condición, dicha dos veces: *"siempre y cuando sea de la misma Sofía, y
# que no tenga otro consolidado o una pre-alerta independiente"*.
#
# **Qué escribe** (`RP-73`): un renglón nuevo en la pre-alerta consolidada,
# vinculado a la caja. Si quedara solo en la tanda, la pre-factura —que
# factura por pre-alerta (`C27-04`)— la cobraría aparte de las cajas con las
# que se midió. Sin PIN, como lo dijo él; queda en el historial del renglón
# (paper_trail) con quién lo hizo.
class UnirAlConsolidado
  class NoSePuede < StandardError; end

  def initialize(paquete:, pre_alerta:)
    @paquete = paquete
    @pre_alerta = pre_alerta
  end

  # Las pre-alertas vivas del cliente que nombran esta caja, por vínculo o por
  # tracking, como `GrupoDeUnion`. Consolidadas **o no**: una independiente
  # también la deja afuera.
  def self.pre_alertas_de(paquete)
    return PreAlerta.none if paquete.cliente_id.nil?

    PreAlerta.activas.where(cliente_id: paquete.cliente_id)
             .joins(:pre_alerta_paquetes)
             .where("pre_alerta_paquetes.paquete_id = :id OR UPPER(pre_alerta_paquetes.tracking) = :t",
                    id: paquete.id, t: paquete.tracking.to_s.upcase)
             .distinct
  end

  # ¿Se le puede ofrecer unirla? Lo usa `PuedenIrJuntas` para elegir el modal.
  def self.se_puede?(paquete, pre_alerta)
    new(paquete: paquete, pre_alerta: pre_alerta).problema.nil?
  end

  def problema
    return "#{codigo} es de otro cliente." if @paquete.cliente_id != @pre_alerta.cliente_id
    return "La pre-alerta #{@pre_alerta.numero_documento} no es un consolidado." unless @pre_alerta.consolidado?
    return "La pre-alerta #{@pre_alerta.numero_documento} ya no está activa." unless PreAlerta.activas.exists?(@pre_alerta.id)
    if @pre_alerta.finalizado? || @pre_alerta.facturado?
      return "La pre-alerta #{@pre_alerta.numero_documento} ya se facturó: no se le agregan cajas."
    end
    return "#{codigo} ya está en una pre-factura." if @paquete.pre_factura_id.present? || @paquete.venta_id.present?

    otra = self.class.pre_alertas_de(@paquete).first
    "#{codigo} ya está en la pre-alerta #{otra.numero_documento}." if otra
  end

  def call
    motivo = problema
    raise NoSePuede, motivo if motivo

    PreAlertaPaquete.transaction do
      @pre_alerta.pre_alerta_paquetes.create!(tracking: tracking_del_renglon, paquete: @paquete,
                                              descripcion: @paquete.descripcion.presence || "Unida en la PESA",
                                              fecha: Date.current)
      # Lo mismo que hace `PreAlertaPaquete.link_tracking!` al vincular: la
      # nota de grupo del consolidado pasa a la caja, si no tenía una.
      if @paquete.notas_consolidacion.blank? && @pre_alerta.notas_grupo.present?
        @paquete.update_column(:notas_consolidacion, @pre_alerta.notas_grupo)
      end
    end
    @pre_alerta
  end

  private

  # El renglón de la pre-alerta solo acepta letras, números y guiones, y el
  # tracking de un paquete puede traer `.`, `_` o `/`. El vínculo va por
  # `paquete_id`, así que normalizar el texto no pierde la caja.
  def tracking_del_renglon
    @paquete.tracking.to_s.upcase.gsub(/[^A-Z0-9-]/, "-")
  end

  def codigo = @paquete.numero_recepcion_visible.presence || @paquete.tracking
end
