# PR-13.d/e: la bitácora de lo que se autorizó.
#
# Sin una pantalla donde mirarlo, todo el mecanismo del PIN es solo fricción en
# el mostrador: se registra pero nadie lo lee. Acá es donde se ve cuánto se
# regaló, quién lo autorizó y por qué.
#
# Muestra los dos casos juntos —cambios de línea en pre-factura y emisión de
# notas— porque son el mismo hecho: plata que se movió sin una tarifa detrás. Si
# estuvieran en dos pantallas, nadie sumaría las dos.
class BitacoraAutorizacionesController < ApplicationController
  before_action :require_supervisor

  def index
    # `preload` y no `includes` para `documento`: es polimórfico y no se puede
    # resolver con un JOIN — Rails tira `EagerLoadPolymorphicError`.
    @autorizaciones = Autorizacion
                      .includes(:autorizado_por, :solicitado_por)
                      .preload(:documento)
                      .recientes
    @autorizaciones = @autorizaciones.by_accion(params[:accion]) if params[:accion].present?
    @autorizaciones = @autorizaciones.by_autorizante(params[:autorizado_por_id]) if params[:autorizado_por_id].present?
    if params[:desde].present? && (desde = Date.parse(params[:desde]) rescue nil)
      @autorizaciones = @autorizaciones.where(created_at: desde.beginning_of_day..)
    end

    @total_descontado = @autorizaciones.by_accion("descuento").sum(:valor_nuevo)
    # Las notas de crédito son plata que se devuelve; van aparte del descuento
    # porque salen de otro documento y se leen distinto.
    @total_notas_credito = @autorizaciones.by_accion("emitir")
                                          .where(documento_type: "NotaCredito")
                                          .sum(:valor_nuevo)
    @autorizaciones = @autorizaciones.page(params[:page]).per(per_page_sanitized)
  end

  private

  # Los mismos que pueden autorizar son los que pueden revisar lo autorizado.
  def require_supervisor
    return if Current.user&.rol_autorizante?

    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion."
  end
end
