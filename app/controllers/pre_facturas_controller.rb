class PreFacturasController < ApplicationController
  before_action :require_feature_access
  before_action :set_pre_factura, only: %i[show edit update confirmar facturar anular]

  def index
    @pre_facturas = PreFactura.includes(:cliente, :creado_por).recientes
    @pre_facturas = apply_filters(@pre_facturas)
    @pre_facturas = @pre_facturas.page(params[:page]).per(25)
  end

  def show
  end

  def new
    @pre_factura = PreFactura.new
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
      redirect_to new_pre_factura_path(cliente_id: cliente.id),
                  alert: "Selecciona al menos un paquete."
      return
    end

    @pre_factura = PreFactura.build_from_paquetes(cliente, paquete_ids, user: Current.user)
    @pre_factura.notas = params.dig(:pre_factura, :notas)

    if @pre_factura.save
      redirect_to edit_pre_factura_path(@pre_factura),
                  notice: "Pre-factura #{@pre_factura.numero} creada."
    else
      @cliente = cliente
      @paquetes_facturables = cliente.paquetes.facturables.includes(:tipo_envio)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @pre_factura.update(pre_factura_params)
      redirect_to edit_pre_factura_path(@pre_factura), notice: "Pre-factura actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def confirmar
    if @pre_factura.confirmar!
      redirect_to edit_pre_factura_path(@pre_factura), notice: "Pre-factura confirmada."
    else
      redirect_to edit_pre_factura_path(@pre_factura), alert: "No se pudo confirmar la pre-factura."
    end
  end

  def facturar
    venta = @pre_factura.facturar!
    if venta
      nd = @pre_factura.nota_debito_auto
      notice =
        if nd
          "Venta #{venta.numero} generada. Se creo #{nd.numero} en estado CREADO - revisala antes de emitir."
        else
          "Venta #{venta.numero} generada."
        end
      redirect_to venta_path(venta), notice: notice
    else
      redirect_to edit_pre_factura_path(@pre_factura), alert: "No se pudo facturar la pre-factura."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to edit_pre_factura_path(@pre_factura), alert: "Error al facturar: #{e.message}"
  end

  def anular
    if @pre_factura.anular!
      redirect_to pre_facturas_path, notice: "Pre-factura anulada."
    else
      redirect_to edit_pre_factura_path(@pre_factura),
                  alert: "No se puede anular una pre-factura ya facturada."
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

  def require_feature_access
    redirect_to(root_path, alert: "No tienes permiso para acceder a esta seccion.") unless can_access?(:pre_facturas)
  end

  def set_pre_factura
    @pre_factura = PreFactura.find(params[:id])
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

  def pre_factura_params
    params.require(:pre_factura).permit(
      :notas, :fecha_trabajo,
      pre_factura_items_attributes: [
        :id, :concepto, :precio_libra, :peso_cobrar, :subtotal, :_destroy
      ]
    )
  end
end
