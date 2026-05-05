class FacturasController < ApplicationController
  before_action :require_feature_access
  before_action :set_factura, only: %i[show edit update confirmar emitir registrar_pago anular pdf enviar_email]

  def index
    @facturas = Factura.sin_proformas.includes(:cliente, :creado_por).recientes
    @facturas = apply_filters(@facturas)
    @facturas = @facturas.page(params[:page]).per(per_page_sanitized)
  end

  def show
  end

  def new
    @factura = Factura.new
    if params[:cliente_id].present?
      @cliente = Cliente.find(params[:cliente_id])
      @paquetes_facturables = @cliente.paquetes
        .facturables
        .includes(:tipo_envio)
        .order(:created_at)
    end
  end

  def create
    cliente = Cliente.find(params[:cliente_id])
    paquete_ids = Array(params[:paquete_ids]).map(&:to_i).reject(&:zero?)

    if paquete_ids.empty?
      redirect_to new_factura_path(cliente_id: cliente.id),
                  alert: "Selecciona al menos un paquete."
      return
    end

    @factura = Factura.build_from_paquetes(cliente, paquete_ids, user: Current.user)
    @factura.notas = params.dig(:factura, :notas)

    if @factura.save
      redirect_to edit_factura_path(@factura),
                  notice: "Factura #{@factura.numero} creada en estado borrador."
    else
      @cliente = cliente
      @paquetes_facturables = cliente.paquetes.facturables.includes(:tipo_envio)
      render :new, status: :unprocessable_entity
    end
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

  # PR-FAC.3c: borrador → confirmado.
  def confirmar
    if @factura.confirmar!
      redirect_to edit_factura_path(@factura), notice: "Factura confirmada."
    else
      redirect_to edit_factura_path(@factura), alert: "No se pudo confirmar la factura."
    end
  end

  # PR-FAC.3c: confirmado → emitido. Cobra al cliente, dispara email.
  def emitir
    if @factura.emitir!
      nd = @factura.nota_debito_auto
      notice =
        if nd
          "Factura #{@factura.numero} emitida. Se creo #{nd.numero} en estado CREADO — revisala antes de emitir."
        else
          "Factura #{@factura.numero} emitida."
        end
      redirect_to factura_path(@factura), notice: notice
    else
      redirect_to edit_factura_path(@factura), alert: "No se pudo emitir la factura."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to edit_factura_path(@factura), alert: "Error al emitir: #{e.message}"
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

  # JSON endpoint usado por el form de new para mostrar paquetes facturables
  # del cliente seleccionado y poblar precios automáticamente.
  def facturables
    cliente = Cliente.find(params[:cliente_id])
    paquetes = cliente.paquetes.facturables.includes(:tipo_envio)
    render json: paquetes.map { |p|
      precio = cliente.categoria_precio&.precio_para(p.tipo_envio) || p.tipo_envio&.precio_libra
      {
        id: p.id,
        guia: ERB::Util.html_escape(p.guia),
        tracking: ERB::Util.html_escape(p.tracking),
        tipo_envio: ERB::Util.html_escape(p.tipo_envio&.nombre.to_s),
        peso_cobrar: p.peso_cobrar.to_f,
        precio_libra: precio.to_f,
        subtotal: ((p.peso_cobrar || 0).to_d * (precio || 0).to_d).round(2).to_f
      }
    }
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
    if params[:fecha_desde].present? && (fecha_desde = Date.parse(params[:fecha_desde]) rescue nil)
      scope = scope.where(fecha_trabajo: fecha_desde..)
    end
    if params[:fecha_hasta].present? && (fecha_hasta = Date.parse(params[:fecha_hasta]) rescue nil)
      scope = scope.where(fecha_trabajo: ..fecha_hasta)
    end
    scope
  end

  def factura_params
    params.require(:factura).permit(
      :notas, :fecha_trabajo,
      factura_items_attributes: [
        :id, :concepto, :precio_libra, :peso_cobrar, :subtotal, :origen, :_destroy
      ]
    )
  end
end
