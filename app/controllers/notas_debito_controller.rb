class NotasDebitoController < ApplicationController
  before_action :require_feature_access
  before_action :set_nota_debito, only: %i[show edit update emitir anular pdf enviar_email]

  def index
    @notas_debito = NotaDebito.includes(:cliente, :venta, :creado_por).recientes
    @notas_debito = apply_filters(@notas_debito)
    @notas_debito = @notas_debito.page(params[:page]).per(per_page_sanitized)
  end

  def show
  end

  def new
    @venta = Venta.find(params[:venta_id]) if params[:venta_id].present?
    @nota_debito =
      if @venta
        NotaDebito.new(
          venta: @venta,
          cliente: @venta.cliente,
          moneda: @venta.moneda,
          motivo: "ajuste_manual",
          estado: "creado"
        )
      else
        NotaDebito.new(moneda: "LPS", motivo: "ajuste_manual", estado: "creado")
      end
  end

  def create
    venta = Venta.find(params.dig(:nota_debito, :venta_id) || params[:venta_id])
    @nota_debito = NotaDebito.new(nota_debito_params)
    @nota_debito.venta   = venta
    @nota_debito.cliente = venta.cliente
    @nota_debito.moneda  = venta.moneda if @nota_debito.moneda.blank?
    @nota_debito.estado  = "creado"
    @nota_debito.creado_por = Current.user

    if @nota_debito.save
      redirect_to @nota_debito, notice: "Nota de debito #{@nota_debito.numero} creada."
    else
      @venta = venta
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    redirect_to(@nota_debito, alert: "Solo se pueden editar notas en estado creado.") unless @nota_debito.creado?
  end

  def update
    unless @nota_debito.creado?
      redirect_to(@nota_debito, alert: "Solo se pueden editar notas en estado creado.") and return
    end

    if @nota_debito.update(nota_debito_params)
      redirect_to @nota_debito, notice: "Nota de debito actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # PR-13.e: emitir es el momento en que el cliente pasa a deber más. La nota se
  # arma libre —su propósito es ajustar a mano— y el control va acá, donde el
  # saldo cambia. Además, un `cajero` puede crear notas de débito, así que los
  # cuatro ojos importan: la emite otro.
  def emitir
    autorizacion = Autorizacion.emitir_nota!(
      nota: @nota_debito, solicitado_por: Current.user, attrs: autorizacion_params
    )

    if autorizacion.persisted?
      NotaDebitoMailer.emitida(@nota_debito).deliver_later if @nota_debito.cliente.email.present?
      redirect_to @nota_debito,
                  notice: "Nota de debito emitida, autorizada por #{autorizacion.autorizado_por.nombre}."
    else
      redirect_to @nota_debito, alert: autorizacion.errors.full_messages.to_sentence
    end
  end

  def anular
    if @nota_debito.anular!
      redirect_to @nota_debito, notice: "Nota de debito anulada."
    else
      redirect_to @nota_debito, alert: "Solo se pueden anular notas emitidas."
    end
  end

  def pdf
    send_data NotaDebitoPdf.new(@nota_debito).render,
              filename: "ND-#{@nota_debito.numero}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  def enviar_email
    if @nota_debito.cliente.email.present? && @nota_debito.cliente.notificar_facturas?
      NotaDebitoMailer.emitida(@nota_debito).deliver_later
      redirect_to @nota_debito, notice: "Email enviado a #{@nota_debito.cliente.email}."
    else
      redirect_to @nota_debito, alert: "El cliente no tiene email configurado o rechazo notificaciones."
    end
  end

  rate_limit to: 5, within: 5.minutes,
             by: -> { params.dig(:autorizacion, :autorizado_por_id).to_s },
             with: -> { redirect_to nota_debito_path(params[:id]),
                                    alert: "Demasiados intentos con ese PIN. Espera unos minutos." },
             only: :emitir

  private

  def autorizacion_params
    params.fetch(:autorizacion, {}).permit(:autorizado_por_id, :pin, :motivo)
  end

  def require_feature_access
    redirect_to(root_path, alert: "No tienes permiso para acceder a esta seccion.") unless can_access?(:notas_debito)
  end

  def set_nota_debito
    @nota_debito = NotaDebito.find(params[:id])
  end

  def apply_filters(scope)
    scope = scope.buscar(params[:q]) if params[:q].present?
    scope = scope.by_estado(params[:estado]) if params[:estado].present?
    scope = scope.by_cliente(params[:cliente_id]) if params[:cliente_id].present?
    scope = scope.by_venta(params[:venta_id]) if params[:venta_id].present?
    scope
  end

  def nota_debito_params
    params.require(:nota_debito).permit(
      :motivo, :notas, :moneda,
      nota_debito_items_attributes: [
        :id, :paquete_id, :concepto, :peso_cobrar, :precio_libra, :subtotal, :_destroy
      ]
    )
  end
end
