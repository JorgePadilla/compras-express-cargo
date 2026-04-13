class FinanciamientosController < ApplicationController
  before_action :require_feature_access
  before_action :set_financiamiento, only: %i[show pagar_cuota cancelar]

  def index
    @financiamientos = Financiamiento.includes(:cliente, :venta).recientes
    @financiamientos = apply_filters(@financiamientos)
    @financiamientos = @financiamientos.page(params[:page]).per(25)
  end

  def show
    @cuotas = @financiamiento.financiamiento_cuotas.order(:numero_cuota)
  end

  def new
    @venta = Venta.find_by(id: params[:venta_id])
    return redirect_to(financiamientos_path, alert: "Selecciona una venta valida.") unless @venta

    @financiamiento = Financiamiento.new(
      venta: @venta,
      cliente: @venta.cliente,
      moneda: @venta.moneda,
      monto_total: @venta.saldo_pendiente,
      frecuencia: "mensual",
      fecha_inicio: Date.current,
      numero_cuotas: 3
    )
  end

  def create
    @financiamiento = Financiamiento.new(financiamiento_params)
    @financiamiento.creado_por = Current.user

    if @financiamiento.save
      @financiamiento.generar_cuotas!
      redirect_to @financiamiento, notice: "Financiamiento #{@financiamiento.numero} creado con #{@financiamiento.numero_cuotas} cuotas."
    else
      @venta = @financiamiento.venta
      render :new, status: :unprocessable_entity
    end
  end

  def pagar_cuota
    cuota = @financiamiento.financiamiento_cuotas.find(params[:cuota_id])

    unless cuota.pendiente? || cuota.vencida?
      redirect_to(@financiamiento, alert: "Esta cuota ya fue pagada.") and return
    end

    venta = @financiamiento.venta
    metodo = params[:metodo_pago] || "efectivo"
    # Cap at venta's remaining saldo to avoid overpayment if someone paid directly on the venta
    monto = [cuota.monto.to_d, venta.saldo_pendiente.to_d].min

    if monto <= 0
      redirect_to(@financiamiento, alert: "La venta ya no tiene saldo pendiente.") and return
    end

    recibo = venta.registrar_pago(monto: monto, metodo_pago: metodo, user: Current.user, notas: "Cuota #{cuota.numero_cuota} - #{@financiamiento.numero}")

    if recibo
      cuota.pagar!(pago: recibo.pago)
      redirect_to @financiamiento, notice: "Cuota #{cuota.numero_cuota} pagada. Recibo #{recibo.numero} generado."
    else
      redirect_to @financiamiento, alert: "No se pudo registrar el pago de la cuota."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @financiamiento, alert: "Error: #{e.message}"
  end

  def cancelar
    if @financiamiento.cancelar!
      redirect_to @financiamiento, notice: "Financiamiento cancelado."
    else
      redirect_to @financiamiento, alert: "Solo se pueden cancelar financiamientos activos."
    end
  end

  private

  def require_feature_access
    redirect_to(root_path, alert: "No tienes permiso para acceder a esta seccion.") unless can_access?(:financiamientos)
  end

  def set_financiamiento
    @financiamiento = Financiamiento.find(params[:id])
  end

  def apply_filters(scope)
    scope = scope.buscar(params[:q]) if params[:q].present?
    scope = scope.by_estado(params[:estado]) if params[:estado].present?
    scope = scope.by_cliente(params[:cliente_id]) if params[:cliente_id].present?
    scope
  end

  def financiamiento_params
    params.require(:financiamiento).permit(
      :venta_id, :cliente_id, :moneda, :monto_total, :numero_cuotas,
      :monto_cuota, :frecuencia, :fecha_inicio, :notas
    )
  end
end
