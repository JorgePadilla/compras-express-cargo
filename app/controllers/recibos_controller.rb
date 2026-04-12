class RecibosController < ApplicationController
  before_action :require_feature_access
  before_action :set_recibo, only: [:show, :pdf]

  def index
    @recibos = Recibo.includes(:cliente, :venta, :pago).recientes
    @recibos = @recibos.by_cliente(params[:cliente_id]) if params[:cliente_id].present?
    if params[:fecha_desde].present? && (fecha_desde = Date.parse(params[:fecha_desde]) rescue nil)
      @recibos = @recibos.where(created_at: fecha_desde.beginning_of_day..)
    end
    if params[:fecha_hasta].present? && (fecha_hasta = Date.parse(params[:fecha_hasta]) rescue nil)
      @recibos = @recibos.where(created_at: ..fecha_hasta.end_of_day)
    end
    @recibos = @recibos.page(params[:page]).per(25)
  end

  def show
  end

  def pdf
    send_data ReciboPdf.new(@recibo).render,
              filename: "recibo-#{@recibo.numero}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  private

  def require_feature_access
    redirect_to(root_path, alert: "No tienes permiso para acceder a esta seccion.") unless can_access?(:recibos)
  end

  def set_recibo
    @recibo = Recibo.find(params[:id])
  end
end
