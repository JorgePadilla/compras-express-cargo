# C26-03 · «Facturar lo que hay»: seguir sin que el grupo esté completo.
#
# Jorge, 2026-09-06: *"hay una posibilidad de que solo estén 2: en ese caso **se
# pone una alerta y se pasa**"*. La primera versión pedía PIN de un jefe; él lo
# corrigió al verlo. La fricción que pidió es **el modal rojo**, no un jefe
# caminando hasta la estación: la línea mueve mil paquetes por manifiesto.
#
# Lo que queda es el registro: la pre-alerta se sella con quién y cuándo, y su
# historial dice **qué faltaba** en ese momento. Es lo que pre-factura va a
# leer cuando le toque cobrar un grupo a medias (`C26-08`).
class PasarGrupoIncompleto
  class YaCompleto < StandardError; end

  def initialize(pre_alerta:, user:)
    @pre_alerta = pre_alerta
    @user = user
  end

  def call
    grupo = GrupoDeUnion.new(pre_alerta: @pre_alerta)
    raise YaCompleto, "El grupo está completo: no hay nada que forzar." if grupo.completo?

    iniciales = @user&.iniciales_display
    @pre_alerta.update!(union_parcial_at: Time.current, union_parcial_por: iniciales)
    @pre_alerta.append_historial!(
      "#{Time.current.strftime('%d/%m/%Y %H:%M')} · Se factura sin el grupo completo (#{iniciales}): " \
      "#{grupo.medidas} de #{grupo.total} medidas. Faltaba #{detalle(grupo)}."
    )
    grupo
  end

  private

  def detalle(grupo)
    grupo.faltantes.map { |c| "#{c.tracking} (#{c.donde})" }.join(", ")
  end
end
