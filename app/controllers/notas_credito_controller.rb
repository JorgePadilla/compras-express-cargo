class NotasCreditoController < ApplicationController
  before_action :require_feature_access
  before_action :set_nota_credito, only: %i[show edit update emitir anular pdf enviar_email]

  def index
    @notas_credito = NotaCredito.includes(:cliente, :venta, :creado_por).recientes
    @notas_credito = apply_filters(@notas_credito)
    @notas_credito = @notas_credito.page(params[:page]).per(25)
  end

  def show
  end

  def new
    @venta = Venta.find(params[:venta_id]) if params[:venta_id].present?
    @nota_credito =
      if @venta
        NotaCredito.new(
          venta: @venta,
          cliente: @venta.cliente,
          moneda: @venta.moneda,
          motivo: "descuento",
          estado: "creado"
        )
      else
        NotaCredito.new(moneda: "LPS", motivo: "descuento", estado: "creado")
      end
  end

  def create
    venta = Venta.find(params.dig(:nota_credito, :venta_id) || params[:venta_id])
    @nota_credito = NotaCredito.new(nota_credito_params)
    @nota_credito.venta   = venta
    @nota_credito.cliente = venta.cliente
    @nota_credito.moneda  = venta.moneda if @nota_credito.moneda.blank?
    @nota_credito.estado  = "creado"
    @nota_credito.creado_por = Current.user

    if @nota_credito.save
      redirect_to @nota_credito, notice: "Nota de credito #{@nota_credito.numero} creada."
    else
      @venta = venta
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    redirect_to(@nota_credito, alert: "Solo se pueden editar notas en estado creado.") unless @nota_credito.creado?
  end

  def update
    unless @nota_credito.creado?
      redirect_to(@nota_credito, alert: "Solo se pueden editar notas en estado creado.") and return
    end

    if @nota_credito.update(nota_credito_params)
      redirect_to @nota_credito, notice: "Nota de credito actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def emitir
    if @nota_credito.emitir!
      NotaCreditoMailer.emitida(@nota_credito).deliver_later if @nota_credito.cliente.email.present?
      redirect_to @nota_credito, notice: "Nota de credito emitida."
    else
      redirect_to @nota_credito, alert: "No se pudo emitir (estado actual: #{@nota_credito.estado})."
    end
  end

  def anular
    if @nota_credito.anular!
      redirect_to @nota_credito, notice: "Nota de credito anulada."
    else
      redirect_to @nota_credito, alert: "Solo se pueden anular notas emitidas."
    end
  end

  def pdf
    send_data NotaCreditoPdf.new(@nota_credito).render,
              filename: "NC-#{@nota_credito.numero}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  def enviar_email
    if @nota_credito.cliente.email.present? && @nota_credito.cliente.notificar_facturas?
      NotaCreditoMailer.emitida(@nota_credito).deliver_later
      redirect_to @nota_credito, notice: "Email enviado a #{@nota_credito.cliente.email}."
    else
      redirect_to @nota_credito, alert: "El cliente no tiene email configurado o rechazo notificaciones."
    end
  end

  private

  def require_feature_access
    redirect_to(root_path, alert: "No tienes permiso para acceder a esta seccion.") unless can_access?(:notas_credito)
  end

  def set_nota_credito
    @nota_credito = NotaCredito.find(params[:id])
  end

  def apply_filters(scope)
    scope = scope.buscar(params[:q]) if params[:q].present?
    scope = scope.by_estado(params[:estado]) if params[:estado].present?
    scope = scope.by_cliente(params[:cliente_id]) if params[:cliente_id].present?
    scope = scope.by_venta(params[:venta_id]) if params[:venta_id].present?
    scope
  end

  def nota_credito_params
    params.require(:nota_credito).permit(
      :motivo, :notas, :moneda,
      nota_credito_items_attributes: [
        :id, :paquete_id, :concepto, :peso_cobrar, :precio_libra, :subtotal, :_destroy
      ]
    )
  end
end
