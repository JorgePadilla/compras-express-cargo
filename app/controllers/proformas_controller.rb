class ProformasController < ApplicationController
  before_action :require_feature_access
  before_action :set_proforma, only: %i[show edit update emitir anular pdf enviar_email]

  def index
    @proformas = Venta.proformas.includes(:cliente, :creado_por).recientes
    @proformas = apply_filters(@proformas)
    @proformas = @proformas.page(params[:page]).per(25)
  end

  def show
  end

  def new
    @proforma = Venta.new(moneda: "LPS", estado: "proforma")
    if params[:cliente_id].present?
      @cliente = Cliente.find(params[:cliente_id])
      if params[:manual].present?
        @manual = true
        @proforma.cliente = @cliente
        @proforma.venta_items.build
      else
        @paquetes_facturables = @cliente.paquetes
          .facturables
          .includes(:tipo_envio)
          .order(:created_at)
      end
    end
  end

  def create
    if params[:paquete_ids].present?
      create_from_paquetes
    else
      create_manual
    end
  end

  def edit
    redirect_to(proforma_path(@proforma), alert: "Solo se pueden editar proformas en estado proforma.") unless @proforma.proforma?
  end

  def update
    unless @proforma.proforma?
      redirect_to(proforma_path(@proforma), alert: "Solo se pueden editar proformas en estado proforma.") and return
    end

    if @proforma.update(proforma_params)
      redirect_to proforma_path(@proforma), notice: "Proforma actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def emitir
    return redirect_to(proforma_path(@proforma), alert: "Solo se pueden emitir proformas.") unless @proforma.proforma?

    if @proforma.emitir_proforma!
      if @proforma.cliente.email.present? && @proforma.cliente.notificar_facturas?
        FacturaMailer.pendiente(@proforma).deliver_later
        @proforma.update_column(:email_pendiente_enviado_at, Time.current)
      end
      redirect_to venta_path(@proforma), notice: "Proforma emitida como factura #{@proforma.numero}."
    else
      redirect_to proforma_path(@proforma), alert: "No se pudo emitir la proforma."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to proforma_path(@proforma), alert: "Error: #{e.message}"
  end

  def anular
    return redirect_to(proforma_path(@proforma), alert: "Solo se pueden anular proformas.") unless @proforma.proforma?

    if @proforma.anular_proforma!
      redirect_to proformas_path, notice: "Proforma anulada."
    else
      redirect_to proforma_path(@proforma), alert: "No se pudo anular la proforma."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to proforma_path(@proforma), alert: "Error: #{e.message}"
  end

  def pdf
    send_data VentaPdf.new(@proforma).render,
              filename: "proforma-#{@proforma.numero}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  def enviar_email
    if @proforma.cliente.email.present?
      ProformaMailer.enviada(@proforma).deliver_later
      redirect_to proforma_path(@proforma), notice: "Email enviado a #{@proforma.cliente.email}."
    else
      redirect_to proforma_path(@proforma), alert: "El cliente no tiene email configurado."
    end
  end

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

  def create_from_paquetes
    cliente = Cliente.find(params[:cliente_id])
    paquete_ids = Array(params[:paquete_ids]).map(&:to_i).reject(&:zero?)

    if paquete_ids.empty?
      redirect_to new_proforma_path(cliente_id: cliente.id),
                  alert: "Selecciona al menos un paquete."
      return
    end

    @proforma = Venta.build_proforma_from_paquetes(
      cliente, paquete_ids,
      user: Current.user,
      notas: params.dig(:proforma, :notas)
    )

    if @proforma.save
      # Reserve paquetes on the proforma (venta_id set, estado stays)
      @proforma.venta_items.includes(:paquete).each do |item|
        item.paquete&.update_column(:venta_id, @proforma.id)
      end
      redirect_to proforma_path(@proforma), notice: "Proforma #{@proforma.numero} creada con #{paquete_ids.size} paquete(s)."
    else
      @cliente = cliente
      @paquetes_facturables = cliente.paquetes.facturables.includes(:tipo_envio)
      render :new, status: :unprocessable_entity
    end
  end

  def create_manual
    @proforma = Venta.new(proforma_params)
    @proforma.estado = "proforma"
    @proforma.creado_por = Current.user

    if @proforma.save
      redirect_to proforma_path(@proforma), notice: "Proforma #{@proforma.numero} creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def require_feature_access
    redirect_to(root_path, alert: "No tienes permiso para acceder a esta seccion.") unless can_access?(:ventas)
  end

  def set_proforma
    @proforma = Venta.find(params[:id])
  end

  def apply_filters(scope)
    scope = scope.buscar(params[:q]) if params[:q].present?
    scope = scope.by_cliente(params[:cliente_id]) if params[:cliente_id].present?
    scope
  end

  def proforma_params
    params.require(:venta).permit(
      :cliente_id, :moneda, :notas,
      venta_items_attributes: [
        :id, :paquete_id, :concepto, :peso_cobrar, :precio_libra, :subtotal, :_destroy
      ]
    )
  end
end
