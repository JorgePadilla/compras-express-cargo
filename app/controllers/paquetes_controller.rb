class PaquetesController < ApplicationController
  before_action :set_paquete, only: [ :show, :edit, :update, :label ]
  before_action :authorize_tracking_actions, only: [ :check_tracking, :search ]

  def index
    @paquetes = base_scope
                  .includes(:cliente, :tipo_envio, :sucursal, :manifiesto,
                            :pre_factura, :venta,
                            pre_alerta_paquetes: :pre_alerta)
                  .order(created_at: :desc)
    @paquetes = apply_filters(@paquetes)
    @paquetes = @paquetes.page(params[:page]).per(25)
    @tipo_envios = TipoEnvio.activos.order(:nombre)
    @sucursales = Sucursal.activas.ordered
    @estados_paquete = Paquete.estados.keys
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

  # Export de la coleccion filtrada (xlsx o pdf). El set de resultados sigue
  # el mismo pipeline que `index` (base_scope + apply_filters) para mantener
  # consistencia usuario: exporta lo que ve.
  def export
    paquetes = export_scope
    respond_to do |format|
      format.xlsx { send_xlsx(paquetes, filename: "paquetes-#{Date.current.iso8601}.xlsx") }
      format.pdf do
        pdf = Paquetes::ListadoPdf.new(paquetes).render
        send_data pdf, filename: "paquetes-#{Date.current.iso8601}.pdf",
                       type: "application/pdf", disposition: "attachment"
      end
    end
  end

  # Imprime (PDF) los paquetes seleccionados via checkbox bulk.
  def bulk_print
    ids = Array(params[:paquete_ids]).reject(&:blank?)
    if ids.empty?
      redirect_to paquetes_path, alert: "Selecciona al menos un paquete."
      return
    end

    paquetes = Paquete.where(id: ids).includes(:cliente, :tipo_envio, :sucursal)
    pdf = Paquetes::ListadoPdf.new(paquetes, titulo: "Paquetes seleccionados (#{paquetes.size})").render
    send_data pdf, filename: "paquetes-seleccion-#{Date.current.iso8601}.pdf",
                   type: "application/pdf", disposition: "attachment"
  end

  # Export xlsx/pdf de solo los paquetes seleccionados.
  def bulk_export
    ids = Array(params[:paquete_ids]).reject(&:blank?)
    if ids.empty?
      redirect_to paquetes_path, alert: "Selecciona al menos un paquete."
      return
    end

    paquetes = Paquete.where(id: ids).includes(:cliente, :tipo_envio, :sucursal, :manifiesto,
                                                pre_alerta_paquetes: :pre_alerta)
    formato = params[:formato].presence_in(%w[xlsx pdf]) || "xlsx"

    if formato == "xlsx"
      send_xlsx(paquetes, filename: "paquetes-seleccion-#{Date.current.iso8601}.xlsx")
    else
      pdf = Paquetes::ListadoPdf.new(paquetes, titulo: "Paquetes seleccionados (#{paquetes.size})").render
      send_data pdf, filename: "paquetes-seleccion-#{Date.current.iso8601}.pdf",
                     type: "application/pdf", disposition: "attachment"
    end
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

  # Genera el XLSX via Axlsx::Package directamente y lo manda como send_data.
  # Evita las idiosincrasias de render xlsx: "..." (que resuelve template
  # segun format y falla si el request llego como HTML).
  def send_xlsx(paquetes, filename:)
    xlsx_package = Axlsx::Package.new
    view = view_context
    view.instance_variable_set(:@xlsx_package, xlsx_package)
    view.xlsx_package = xlsx_package if view.respond_to?(:xlsx_package=)
    view.render(template: "paquetes/export", formats: [ :xlsx ], handlers: [ :axlsx ], locals: { paquetes: paquetes })
    send_data xlsx_package.to_stream.read,
              filename: filename,
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
              disposition: "attachment"
  end

  def set_paquete
    @paquete = Paquete.find(params[:id])
  end

  def authorize_tracking_actions
    require_role(:supervisor_miami, :digitador_miami, :supervisor_prefactura, :supervisor_caja, :cajero)
  end

  def base_scope
    if params[:incluir_mas_1_ano] == "1"
      Paquete.all
    elsif params[:incluir_3_12_meses] == "1"
      Paquete.where(created_at: 1.year.ago..)
    else
      Paquete.where(created_at: 3.months.ago..)
    end
  end

  # Mismos filtros que index pero sin paginacion (para exports). Cap defensivo
  # para evitar generar exports imposibles de manejar en memoria.
  EXPORT_CAP = 5_000

  def export_scope
    scope = base_scope
              .includes(:cliente, :tipo_envio, :sucursal, :manifiesto,
                        pre_alerta_paquetes: :pre_alerta)
              .order(created_at: :desc)
    apply_filters(scope).limit(EXPORT_CAP)
  end

  def apply_filters(scope)
    scope = scope.buscar(params[:q]) if params[:q].present?

    # Multi-select: estado, tipo_envio, sucursal
    estados = Array(params[:estados]).reject(&:blank?)
    scope = scope.by_estados(estados) if estados.any?
    # Back-compat: param single `estado`
    scope = scope.by_estado(params[:estado]) if params[:estado].present? && estados.empty?

    tipos = Array(params[:tipo_envio_ids]).reject(&:blank?)
    scope = scope.by_tipos_envio(tipos) if tipos.any?
    scope = scope.by_tipo_envio(params[:tipo_envio_id]) if params[:tipo_envio_id].present? && tipos.empty?

    sucursales = Array(params[:sucursal_ids]).reject(&:blank?)
    scope = scope.by_sucursal(sucursales) if sucursales.any?

    scope = scope.by_cliente(params[:cliente_id]) if params[:cliente_id].present?

    if params[:fecha_desde].present? && (fecha_desde = Date.parse(params[:fecha_desde]) rescue nil)
      scope = scope.where(fecha_recibido_miami: fecha_desde...)
    end
    if params[:fecha_hasta].present? && (fecha_hasta = Date.parse(params[:fecha_hasta]) rescue nil)
      scope = scope.where(fecha_recibido_miami: ...fecha_hasta.end_of_day)
    end

    # Quick toggles
    scope = scope.where(estado: "facturado") if params[:solo_facturados] == "1"
    # incluir_facturados: default muestra todos; si == "0" los excluye
    scope = scope.where.not(estado: "facturado") if params[:incluir_facturados] == "0"
    scope = scope.where(pre_alerta: false) if params[:sin_prealerta] == "1"
    scope = scope.where(estado: "anulado") if params[:solo_anulados] == "1"
    scope = scope.where(pre_factura: true) if params[:solo_prefactura] == "1"
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
