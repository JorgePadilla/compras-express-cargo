class CajaController < ApplicationController
  before_action :require_feature_access

  def show
    @apertura = AperturaCaja.del_dia
    if @apertura&.abierta?
      @pagos = @apertura.pagos.includes(:venta, :cliente).order(created_at: :desc)
      @ingresos = @apertura.ingresos_caja.recientes
      @egresos = @apertura.egresos_caja.recientes
    end
  end

  def apertura
    if AperturaCaja.del_dia
      redirect_to caja_path, alert: "Ya existe una apertura de caja para hoy." and return
    end

    @apertura = AperturaCaja.new(
      fecha: Date.current,
      monto_apertura: params[:monto_apertura].to_d,
      notas_apertura: params[:notas_apertura],
      abierta_por: Current.user
    )

    if @apertura.save
      redirect_to caja_path, notice: "Caja abierta exitosamente."
    else
      redirect_to caja_path, alert: "No se pudo abrir la caja: #{@apertura.errors.full_messages.join(', ')}"
    end
  end

  def cierre
    @apertura = AperturaCaja.del_dia

    unless @apertura&.abierta?
      redirect_to caja_path, alert: "No hay caja abierta para cerrar." and return
    end

    if @apertura.cerrar!(monto_cierre: params[:monto_cierre].to_d, user: Current.user, notas: params[:notas_cierre])
      redirect_to caja_path, notice: "Caja cerrada exitosamente."
    else
      redirect_to caja_path, alert: "No se pudo cerrar la caja."
    end
  end

  def historial
    @aperturas = AperturaCaja.recientes.page(params[:page]).per(25)
  end

  private

  def require_feature_access
    redirect_to(root_path, alert: "No tienes permiso para acceder a esta seccion.") unless can_access?(:caja)
  end
end
