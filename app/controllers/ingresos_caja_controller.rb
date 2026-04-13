class IngresosCajaController < ApplicationController
  before_action :require_feature_access
  before_action :require_caja_abierta, only: %i[new create]

  def index
    @apertura = AperturaCaja.del_dia
    @ingresos = if @apertura
      @apertura.ingresos_caja.includes(:registrado_por).recientes
    else
      IngresoCaja.none
    end
  end

  def new
    @ingreso = @apertura.ingresos_caja.build
  end

  def create
    @ingreso = @apertura.ingresos_caja.build(ingreso_params)
    @ingreso.registrado_por = Current.user

    if @ingreso.save
      redirect_to ingreso_caja_path(@ingreso), notice: "Ingreso #{@ingreso.numero} registrado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @ingreso = IngresoCaja.find(params[:id])
  end

  private

  def require_feature_access
    redirect_to(root_path, alert: "No tienes permiso para acceder a esta seccion.") unless can_access?(:caja)
  end

  def require_caja_abierta
    @apertura = AperturaCaja.del_dia
    unless @apertura&.abierta?
      redirect_to caja_path, alert: "Debes abrir caja antes de registrar ingresos."
    end
  end

  def ingreso_params
    params.require(:ingreso_caja).permit(:monto, :concepto, :metodo_pago, :notas)
  end
end
