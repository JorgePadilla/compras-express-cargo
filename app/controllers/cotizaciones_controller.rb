class CotizacionesController < ApplicationController
  before_action :require_feature_access
  before_action :set_cotizacion, only: %i[show edit update enviar aceptar rechazar generar_proforma pdf enviar_email]

  def index
    @cotizaciones = Cotizacion.includes(:cliente, :creado_por).recientes
    @cotizaciones = apply_filters(@cotizaciones)
    @cotizaciones = @cotizaciones.page(params[:page]).per(25)
  end

  def show
  end

  def new
    @cotizacion = Cotizacion.new(moneda: "LPS", estado: "borrador", vigencia_dias: 30)
    @cotizacion.cotizacion_items.build
  end

  def create
    @cotizacion = Cotizacion.new(cotizacion_params)
    @cotizacion.estado = "borrador"
    @cotizacion.creado_por = Current.user

    if @cotizacion.save
      redirect_to @cotizacion, notice: "Cotizacion #{@cotizacion.numero} creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    redirect_to(@cotizacion, alert: "Solo se pueden editar cotizaciones en estado borrador.") unless @cotizacion.borrador?
  end

  def update
    unless @cotizacion.borrador?
      redirect_to(@cotizacion, alert: "Solo se pueden editar cotizaciones en estado borrador.") and return
    end

    if @cotizacion.update(cotizacion_params)
      redirect_to @cotizacion, notice: "Cotizacion actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def enviar
    if @cotizacion.enviar!
      CotizacionMailer.enviada(@cotizacion).deliver_later if @cotizacion.cliente.email.present?
      @cotizacion.update_column(:email_enviado_at, Time.current)
      redirect_to @cotizacion, notice: "Cotizacion enviada al cliente."
    else
      redirect_to @cotizacion, alert: "No se pudo enviar (estado actual: #{@cotizacion.estado})."
    end
  end

  def aceptar
    if @cotizacion.aceptar!
      redirect_to @cotizacion, notice: "Cotizacion aceptada."
    else
      redirect_to @cotizacion, alert: "Solo se pueden aceptar cotizaciones enviadas."
    end
  end

  def rechazar
    if @cotizacion.rechazar!
      redirect_to @cotizacion, notice: "Cotizacion rechazada."
    else
      redirect_to @cotizacion, alert: "Solo se pueden rechazar cotizaciones enviadas."
    end
  end

  def generar_proforma
    proforma = @cotizacion.generar_proforma!(user: Current.user)
    if proforma
      redirect_to proforma_path(proforma), notice: "Proforma #{proforma.numero} generada desde cotizacion."
    else
      redirect_to @cotizacion, alert: "No se pudo generar la proforma. Verifica que la cotizacion este aceptada."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @cotizacion, alert: "Error: #{e.message}"
  end

  def pdf
    send_data CotizacionPdf.new(@cotizacion).render,
              filename: "cotizacion-#{@cotizacion.numero}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  def enviar_email
    if @cotizacion.cliente.email.present?
      CotizacionMailer.enviada(@cotizacion).deliver_later
      @cotizacion.update_column(:email_enviado_at, Time.current)
      redirect_to @cotizacion, notice: "Email enviado a #{@cotizacion.cliente.email}."
    else
      redirect_to @cotizacion, alert: "El cliente no tiene email configurado."
    end
  end

  private

  def require_feature_access
    redirect_to(root_path, alert: "No tienes permiso para acceder a esta seccion.") unless can_access?(:cotizaciones)
  end

  def set_cotizacion
    @cotizacion = Cotizacion.find(params[:id])
  end

  def apply_filters(scope)
    scope = scope.buscar(params[:q]) if params[:q].present?
    scope = scope.by_estado(params[:estado]) if params[:estado].present?
    scope = scope.by_cliente(params[:cliente_id]) if params[:cliente_id].present?
    scope
  end

  def cotizacion_params
    params.require(:cotizacion).permit(
      :cliente_id, :moneda, :notas, :terminos, :vigencia_dias,
      cotizacion_items_attributes: [
        :id, :paquete_id, :concepto, :cantidad, :precio_unitario,
        :peso_cobrar, :precio_libra, :subtotal, :_destroy
      ]
    )
  end
end
