class PaquetesController < ApplicationController
  before_action :set_paquete, only: [ :show, :edit, :update, :label, :destroy ]
  before_action :authorize_tracking_actions, only: [ :check_tracking, :search ]
  before_action :authorize_edit, only: [ :edit, :update ]
  before_action :authorize_delete, only: [ :destroy ]

  # Whitelist de columnas ordenables. Mapea param `sort` -> SQL fragment.
  # Cualquier otro valor cae al default (created_at desc).
  SORTABLE_COLUMNS = {
    "fecha_recibido"   => "paquetes.fecha_recibido_miami",
    "fecha_disponible" => "paquetes.fecha_disponible",
    "numero_recepcion" => "paquetes.numero_recepcion",
    "tracking"         => "paquetes.tracking",
    "cliente"          => "clientes.nombre",
    "estado"           => "paquetes.estado",
    "tipo_envio"       => "tipo_envios.codigo",
    "created_at"       => "paquetes.created_at"
  }.freeze

  EDIT_ROLES   = %w[admin supervisor_miami supervisor_prefactura].freeze
  DELETE_ROLES = %w[admin].freeze

  def index
    @paquetes = base_scope
                  .includes(:cliente, :tipo_envio, :sucursal, :manifiesto,
                            :pre_factura, :venta,
                            pre_alerta_paquetes: :pre_alerta)
    @paquetes = apply_filters(@paquetes)
    @paquetes = apply_sort(@paquetes)
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

  def destroy
    if @paquete.destroy
      redirect_to paquetes_path, notice: "Paquete eliminado."
    else
      redirect_to @paquete, alert: "No se puede eliminar: #{@paquete.errors.full_messages.to_sentence}"
    end
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

  # Genera el XLSX via Axlsx::Package directo (sin template) y lo manda
  # como send_data. Construir el workbook en Ruby evita los problemas de
  # binding de `xlsx_package` cuando el request llega como HTML (forms POST).
  def send_xlsx(paquetes, filename:)
    package = build_xlsx_package(paquetes)
    send_data package.to_stream.read,
              filename: filename,
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
              disposition: "attachment"
  end

  def build_xlsx_package(paquetes)
    package = Axlsx::Package.new
    wb = package.workbook

    bold_header = wb.styles.add_style(b: true, bg_color: "1B2559", fg_color: "FFFFFF",
                                       border: { style: :thin, color: "DDDDDD" },
                                       alignment: { vertical: :center })
    date_style = wb.styles.add_style(format_code: "dd/mm/yyyy")

    wb.add_worksheet(name: "Paquetes") do |sheet|
      sheet.add_row([
        "F. Recibido", "F. Disponible", "N° Recepción", "Tracking",
        "Cliente Código", "Cliente Nombre", "Estado", "Tipo Envío",
        "Sucursal", "Consolidado", "Contenido", "Guía", "Pre-Alerta",
        "Pre-Factura", "Factura"
      ], style: bold_header)

      paquetes.each do |p|
        pa = p.pre_alerta_paquetes.first&.pre_alerta
        row_styles = [ date_style, date_style, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil ]
        sheet.add_row([
          p.fecha_recibido_miami&.to_date || p.created_at.to_date,
          p.fecha_disponible&.to_date,
          p.numero_recepcion.presence || "—",
          p.tracking.to_s,
          p.cliente.codigo.to_s,
          p.cliente.nombre_completo.to_s,
          p.estado.to_s.humanize,
          p.tipo_envio&.codigo&.upcase || "—",
          p.sucursal&.nombre || "—",
          p.consolidado? ? "Sí" : "No",
          p.descripcion.to_s,
          p.guia.to_s,
          pa&.numero_documento || "—",
          p.pre_factura&.numero || "—",
          p.venta&.numero || "—"
        ], style: row_styles)
      end

      sheet.column_widths 12, 12, 14, 20, 12, 28, 18, 10, 18, 12, 40, 14, 14, 14, 14
    end

    package
  end

  def set_paquete
    @paquete = Paquete.find(params[:id])
  end

  def authorize_tracking_actions
    require_role(:supervisor_miami, :digitador_miami, :supervisor_prefactura, :supervisor_caja, :cajero)
  end

  def authorize_edit
    return if Current.user&.admin?
    return if EDIT_ROLES.include?(Current.user&.rol)
    redirect_to paquetes_path, alert: "No tienes permiso para editar paquetes."
  end

  def authorize_delete
    return if Current.user&.admin?
    return if DELETE_ROLES.include?(Current.user&.rol)
    redirect_to paquetes_path, alert: "No tienes permiso para eliminar paquetes."
  end

  def apply_sort(scope)
    column = SORTABLE_COLUMNS[params[:sort]] || "paquetes.created_at"
    direction = params[:dir].to_s.downcase == "asc" ? "asc" : "desc"

    # Si se ordena por columna de un join (clientes.nombre, tipo_envios.codigo)
    # asegurar el LEFT JOIN explicito (los includes no garantizan join SQL).
    if column.start_with?("clientes.")
      scope = scope.left_joins(:cliente)
    elsif column.start_with?("tipo_envios.")
      scope = scope.left_joins(:tipo_envio)
    end

    scope.order(Arel.sql("#{column} #{direction} NULLS LAST"))
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
