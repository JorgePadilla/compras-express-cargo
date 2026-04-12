class VentasController < ApplicationController
  before_action :require_feature_access
  before_action :set_venta, only: %i[show edit update registrar_pago anular pdf enviar_email]

  def index
    @ventas = Venta.sin_proformas.includes(:cliente, :creado_por).recientes
    @ventas = apply_filters(@ventas)
    @ventas = @ventas.page(params[:page]).per(25)
  end

  def show
  end

  def edit
  end

  def update
    if @venta.update(venta_params)
      redirect_to edit_venta_path(@venta), notice: "Venta actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def registrar_pago
    monto = params[:monto] || params.dig(:pago, :monto)
    metodo = params[:metodo_pago] || params.dig(:pago, :metodo_pago)
    notas  = params[:notas] || params.dig(:pago, :notas)

    if monto.blank? || metodo.blank?
      redirect_to venta_path(@venta), alert: "Debes indicar monto y metodo de pago." and return
    end

    recibo = @venta.registrar_pago(monto: monto, metodo_pago: metodo, user: Current.user, notas: notas)

    if recibo
      redirect_to recibo_path(recibo), notice: "Pago registrado. Recibo #{recibo.numero} generado."
    else
      redirect_to venta_path(@venta), alert: "No se pudo registrar el pago."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to venta_path(@venta), alert: "Error: #{e.message}"
  end

  def anular
    if @venta.anular!
      redirect_to ventas_path, notice: "Venta anulada."
    else
      redirect_to venta_path(@venta),
                  alert: "No se puede anular una venta ya pagada."
    end
  end

  def pdf
    send_data VentaPdf.new(@venta).render,
              filename: "factura-#{@venta.numero}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  def enviar_email
    if @venta.cliente.email.present? && @venta.cliente.notificar_facturas?
      FacturaMailer.pendiente(@venta).deliver_later
      @venta.update_column(:email_pendiente_enviado_at, Time.current)
      redirect_to venta_path(@venta), notice: "Email enviado a #{@venta.cliente.email}."
    else
      redirect_to venta_path(@venta), alert: "El cliente no tiene email configurado o rechazo notificaciones."
    end
  end

  private

  def require_feature_access
    redirect_to(root_path, alert: "No tienes permiso para acceder a esta seccion.") unless can_access?(:ventas)
  end

  def set_venta
    @venta = Venta.find(params[:id])
  end

  def apply_filters(scope)
    scope = scope.buscar(params[:q]) if params[:q].present?
    scope = scope.by_estado(params[:estado]) if params[:estado].present?
    scope = scope.by_cliente(params[:cliente_id]) if params[:cliente_id].present?
    scope
  end

  def venta_params
    params.require(:venta).permit(:notas)
  end
end
