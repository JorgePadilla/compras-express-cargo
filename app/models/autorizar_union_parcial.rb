# C26-03 · Facturar lo que hay: la excepción del grupo consolidado.
#
# Jorge: *"pueden haber excepciones donde toque facturar lo que se encuentre,
# pero se debe mostrar un modal rojo grande con el problema"*.
#
# **Lleva PIN de un jefe**, como toda excepción que cambia plata en este
# sistema (precio, peso, cobro por volumen): el operario de medición no es jefe,
# y el modal rojo existe justamente para meter fricción. `Autorizacion` es
# polimórfica, así que la pre-alerta entra sin tabla nueva y cae en la bitácora
# de `/autorizaciones` sola. Plantilla: `MarcarCobroExcepcion`.
class AutorizarUnionParcial
  ROLES = User::ROLES_AUTORIZANTES

  class NoPermitido < StandardError; end
  class SinMotivo   < StandardError; end
  class YaCompleto  < StandardError; end

  def initialize(pre_alerta:, supervisor:, pin:, motivo:, solicitado_por: nil)
    @pre_alerta = pre_alerta
    @supervisor = supervisor
    @pin = pin.to_s
    @motivo = motivo.to_s
    @solicitado_por = solicitado_por || supervisor
  end

  def call
    grupo = GrupoDeUnion.new(@pre_alerta)
    validar!(grupo)

    autorizacion = nil
    PreAlerta.transaction do
      autorizacion = Autorizacion.new(
        documento: @pre_alerta,
        solicitado_por: @solicitado_por,
        autorizado_por: @supervisor,
        accion: "union_parcial",
        concepto: @pre_alerta.numero_documento,
        motivo: @motivo,
        detalle: detalle(grupo),
        pin: @pin
      )
      autorizacion.save!
      @pre_alerta.update!(union_parcial_at: Time.current, union_parcial_por: @supervisor.iniciales_display)
      @pre_alerta.append_historial!("#{Time.current.strftime('%d/%m/%Y %H:%M')} · Facturar parcial autorizado por " \
                                    "#{@supervisor.iniciales_display}: #{detalle(grupo)}. Motivo: #{@motivo}")
    end
    autorizacion
  end

  private

  def validar!(grupo)
    raise NoPermitido, "Ese usuario no puede autorizar: hace falta un jefe con PIN." unless autorizado?
    raise SinMotivo, "El motivo es obligatorio: es el punto del registro." if @motivo.blank?
    raise YaCompleto, "El grupo está completo: no hay nada que forzar." if grupo.completo?
  end

  def autorizado?
    @supervisor.present? && @supervisor.activo? &&
      @supervisor.pin_digest.present? && @supervisor.tiene_rol?(ROLES)
  end

  def detalle(grupo)
    "#{grupo.medidos} de #{grupo.total} medidos; faltan #{grupo.faltantes.map(&:tracking).join(', ')}"
  end
end
