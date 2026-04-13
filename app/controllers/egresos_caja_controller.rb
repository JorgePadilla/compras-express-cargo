class EgresosCajaController < ApplicationController
  before_action :require_feature_access
  before_action :require_caja_abierta, only: %i[new create]

  def index
    @apertura = AperturaCaja.del_dia
    @egresos = if @apertura
      @apertura.egresos_caja.includes(:registrado_por).recientes
    else
      EgresoCaja.none
    end
  end

  def new
    @egreso = @apertura.egresos_caja.build
  end

  def create
    @egreso = @apertura.egresos_caja.build(egreso_params)
    @egreso.registrado_por = Current.user

    if @egreso.save
      redirect_to egreso_caja_path(@egreso), notice: "Egreso #{@egreso.numero} registrado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @egreso = EgresoCaja.find(params[:id])
  end

  private

  def require_feature_access
    redirect_to(root_path, alert: "No tienes permiso para acceder a esta seccion.") unless can_access?(:caja)
  end

  def require_caja_abierta
    @apertura = AperturaCaja.del_dia
    unless @apertura&.abierta?
      redirect_to caja_path, alert: "Debes abrir caja antes de registrar egresos."
    end
  end

  def egreso_params
    params.require(:egreso_caja).permit(:monto, :concepto, :metodo_pago, :categoria, :notas)
  end
end
