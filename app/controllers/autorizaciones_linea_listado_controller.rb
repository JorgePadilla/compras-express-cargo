# PR-13.d: la bitácora de lo que se autorizó.
#
# Sin una pantalla donde mirarlo, todo el mecanismo del PIN es solo fricción en
# el mostrador: se registra pero nadie lo lee. Acá es donde se ve cuánto se
# regaló, quién lo autorizó y por qué.
class AutorizacionesLineaListadoController < ApplicationController
  before_action :require_supervisor

  def index
    @autorizaciones = AutorizacionLinea
                      .includes(:autorizado_por, :solicitado_por, pre_factura: :cliente)
                      .recientes
    @autorizaciones = @autorizaciones.by_accion(params[:accion]) if params[:accion].present?
    @autorizaciones = @autorizaciones.by_autorizante(params[:autorizado_por_id]) if params[:autorizado_por_id].present?
    if params[:desde].present? && (desde = Date.parse(params[:desde]) rescue nil)
      @autorizaciones = @autorizaciones.where(created_at: desde.beginning_of_day..)
    end

    @total_descontado = @autorizaciones.by_accion("descuento").sum(:valor_nuevo)
    @autorizaciones = @autorizaciones.page(params[:page]).per(per_page_sanitized)
  end

  private

  # Los mismos que pueden autorizar son los que pueden revisar lo autorizado.
  def require_supervisor
    return if Current.user&.rol_autorizante?

    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion."
  end
end
