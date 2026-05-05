class FacturasController < ApplicationController
  before_action :require_feature_access
  before_action :set_factura, only: %i[show edit update registrar_pago anular pdf enviar_email]

  def index
    @facturas = Factura.sin_proformas.includes(:cliente, :creado_por).recientes
    @facturas = apply_filters(@facturas)
    @facturas = @facturas.page(params[:page]).per(per_page_sanitized)
  end

  def show
  end

  def edit
  end

  def update
    if @factura.update(factura_params)
      redirect_to edit_factura_path(@factura), notice: "Factura actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def registrar_pago
    monto = params[:monto] || params.dig(:pago, :monto)
    metodo = params[:metodo_pago] || params.dig(:pago, :metodo_pago)
    notas  = params[:notas] || params.dig(:pago, :notas)

    if monto.blank? || metodo.blank?
      redirect_to factura_path(@factura), alert: "Debes indicar monto y metodo de pago." and return
    end

    recibo = @factura.registrar_pago(monto: monto, metodo_pago: metodo, user: Current.user, notas: notas)

    if recibo
      redirect_to recibo_path(recibo), notice: "Pago registrado. Recibo #{recibo.numero} generado."
    else
      redirect_to factura_path(@factura), alert: "No se pudo registrar el pago."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to factura_path(@factura), alert: "Error: #{e.message}"
  end

  def anular
    if @factura.anular!
      redirect_to facturas_path, notice: "Factura anulada."
    else
      redirect_to factura_path(@factura),
                  alert: "No se puede anular una factura ya pagada."
    end
  end

  def pdf
    send_data FacturaPdf.new(@factura).render,
              filename: "factura-#{@factura.numero}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  def enviar_email
    if @factura.cliente.email.present? && @factura.cliente.notificar_facturas?
      FacturaMailer.pendiente(@factura).deliver_later
      @factura.update_column(:email_pendiente_enviado_at, Time.current)
      redirect_to factura_path(@factura), notice: "Email enviado a #{@factura.cliente.email}."
    else
      redirect_to factura_path(@factura), alert: "El cliente no tiene email configurado o rechazo notificaciones."
    end
  end

  private

  def require_feature_access
    redirect_to(root_path, alert: "No tienes permiso para acceder a esta seccion.") unless can_access?(:facturas)
  end

  def set_factura
    @factura = Factura.find(params[:id])
  end

  def apply_filters(scope)
    scope = scope.buscar(params[:q]) if params[:q].present?
    scope = scope.by_estado(params[:estado]) if params[:estado].present?
    scope = scope.by_cliente(params[:cliente_id]) if params[:cliente_id].present?
    scope
  end

  def factura_params
    params.require(:factura).permit(:notas)
  end
end
