class CajaController < ApplicationController
  before_action :require_feature_access

  def show
    @apertura = AperturaCaja.del_dia
    if @apertura&.abierta?
      @pagos = @apertura.pagos.includes(:venta, :cliente).order(created_at: :desc)
      @ingresos = @apertura.ingresos_caja.includes(:registrado_por).recientes
      @egresos = @apertura.egresos_caja.includes(:registrado_por).recientes
    end
  end

  def apertura
    if AperturaCaja.del_dia
      redirect_to caja_path, alert: "Ya existe una apertura de caja para hoy." and return
    end

    @apertura = AperturaCaja.new(apertura_params)
    @apertura.fecha = Date.current
    @apertura.abierta_por = Current.user

    if @apertura.save
      redirect_to caja_path, notice: "Caja abierta exitosamente."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def cierre
    @apertura = AperturaCaja.del_dia

    unless @apertura&.abierta?
      redirect_to caja_path, alert: "No hay caja abierta para cerrar." and return
    end

    if @apertura.cerrar!(monto_cierre: cierre_params[:monto_cierre].to_d, user: Current.user, notas: cierre_params[:notas_cierre])
      redirect_to caja_path, notice: "Caja cerrada exitosamente."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def historial
    @aperturas = AperturaCaja.recientes.page(params[:page]).per(25)
  end

  private

  def require_feature_access
    redirect_to(root_path, alert: "No tienes permiso para acceder a esta seccion.") unless can_access?(:caja)
  end

  def apertura_params
    params.permit(:monto_apertura, :notas_apertura)
  end

  def cierre_params
    params.permit(:monto_cierre, :notas_cierre)
  end
end
