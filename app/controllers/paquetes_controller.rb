class PaquetesController < ApplicationController
  before_action :set_paquete, only: [ :show, :edit, :update, :label ]
  before_action :authorize_tracking_actions, only: [ :check_tracking, :search ]

  def index
    @paquetes = base_scope.includes(:cliente, :tipo_envio).order(created_at: :desc)
    @paquetes = apply_filters(@paquetes)
    @paquetes = @paquetes.page(params[:page]).per(25)
    @tipo_envios = TipoEnvio.activos.order(:nombre)
  end

  def show
  end

  def edit
    @tipo_envios = TipoEnvio.activos.order(:nombre)
    @carriers = Carrier.where(activo: true).order(:nombre)
  end

  def update
    if @paquete.update(paquete_params)
      redirect_to @paquete, notice: "Paquete actualizado exitosamente."
    else
      @tipo_envios = TipoEnvio.activos.order(:nombre)
      @carriers = Carrier.where(activo: true).order(:nombre)
      render :edit, status: :unprocessable_entity
    end
  end

  def label
    render layout: "print"
  end

  def check_tracking
    paquete = Paquete.where(tracking: params[:tracking]).order(created_at: :desc).first

    if paquete
      render json: {
        exists: true,
        terminal: paquete.estado_terminal?,
        guia: ERB::Util.html_escape(paquete.guia),
        estado: ERB::Util.html_escape(paquete.estado),
        cliente: ERB::Util.html_escape(paquete.cliente.nombre_completo),
        fecha: paquete.fecha_recibido_miami&.strftime("%d/%m/%Y"),
        count: Paquete.where(tracking: params[:tracking]).count
      }
    else
      render json: { exists: false }
    end
  end

  def search
    paquetes = Paquete.sin_manifiesto
      .includes(:cliente)
      .buscar(params[:q])
      .limit(10)

    render json: paquetes.map { |p|
      {
        id: p.id,
        guia: ERB::Util.html_escape(p.guia),
        tracking: ERB::Util.html_escape(p.tracking),
        cliente: ERB::Util.html_escape(p.cliente.nombre_completo),
        cliente_codigo: ERB::Util.html_escape(p.cliente.codigo),
        estado: ERB::Util.html_escape(p.estado),
        peso_cobrar: p.peso_cobrar.to_f
      }
    }
  end

  private

  def set_paquete
    @paquete = Paquete.find(params[:id])
  end

  def authorize_tracking_actions
    require_role(:supervisor_miami, :digitador_miami, :supervisor_prefactura, :supervisor_caja, :cajero)
  end

  def base_scope
    if params[:incluir_antiguos] == "1"
      Paquete.all
    else
      Paquete.where(created_at: 6.months.ago..)
    end
  end

  def apply_filters(scope)
    scope = scope.buscar(params[:q]) if params[:q].present?
    scope = scope.by_estado(params[:estado]) if params[:estado].present?
    scope = scope.by_tipo_envio(params[:tipo_envio_id]) if params[:tipo_envio_id].present?
    scope = scope.by_cliente(params[:cliente_id]) if params[:cliente_id].present?
    if params[:fecha_desde].present? && (fecha_desde = Date.parse(params[:fecha_desde]) rescue nil)
      scope = scope.where(fecha_recibido_miami: fecha_desde...)
    end
    if params[:fecha_hasta].present? && (fecha_hasta = Date.parse(params[:fecha_hasta]) rescue nil)
      scope = scope.where(fecha_recibido_miami: ...fecha_hasta.end_of_day)
    end
    scope = scope.where(pre_factura: true) if params[:solo_prefactura] == "1"
    scope = scope.where(estado: "anulado") if params[:solo_anulados] == "1"
    scope = scope.where(pre_alerta: false) if params[:sin_prealerta] == "1"
    scope = scope.where(pre_factura: false) if params[:sin_prefactura] == "1"
    scope
  end

  def paquete_params
    params.require(:paquete).permit(
      :tracking, :cliente_id, :tipo_envio_id, :estado, :peso,
      :alto, :largo, :ancho, :cantidad_productos, :cantidad_paquetes,
      :numero_caja, :descripcion, :remitente, :expedido_por, :proveedor,
      :notas_internas, :pre_alerta, :pre_factura,
      :solicito_cambio_servicio, :retener_miami
    )
  end
end
