class EtiquetarController < ApplicationController
  before_action :authorize_etiquetar

  def index
    @paquete = Paquete.new
    @paquetes_hoy = paquetes_hoy_count
    @tipo_envios = TipoEnvio.activos.order(:nombre)
    @carriers = Carrier.where(activo: true).order(:nombre)
  end

  def create
    cantidad = paquete_params[:cantidad_paquetes].to_i

    if cantidad > 1
      create_split(cantidad)
    else
      create_single
    end
  end

  private

  def create_single
    # Reconciliación: si ya existe un paquete "esperado" creado desde una
    # pre-alerta con este tracking, lo transicionamos en lugar de crear
    # uno nuevo (evita duplicados).
    existing = Paquete.where(estado: "pre_alerta_estado")
                      .find_by("UPPER(tracking) = ?", paquete_params[:tracking].to_s.strip.upcase)

    if existing
      @paquete = existing
      @paquete.assign_attributes(paquete_params)
    else
      @paquete = Paquete.new(paquete_params)
    end
    @paquete.estado = "empacado"
    @paquete.user = Current.user
    if (flag = pre_factura_flag_param) != :missing
      @paquete[:pre_factura] = flag
    end

    if @paquete.save
      link_pre_alertas(@paquete)
      @paquetes_hoy = paquetes_hoy_count

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("paquetes-counter", @paquetes_hoy.to_s),
            turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { notice: "Paquete #{@paquete.guia} guardado exitosamente." }),
            turbo_stream.append("etiquetar-events", "<div data-etiquetar-target='event' data-action='paquete-saved' data-guia='#{@paquete.guia}' data-print='#{params[:print]}' data-paquete-id='#{@paquete.id}'></div>")
          ]
        end
        format.html do
          redirect_to etiquetar_path, notice: "Paquete #{@paquete.guia} guardado exitosamente."
        end
      end
    else
      render_create_error
    end
  end

  # Crea N paquetes "hijos" para un tracking dividido en varias cajas físicas.
  # El digitador llenó los datos una sola vez; el sistema replica y asigna
  # numero_caja 1..N. Imprime N etiquetas si se pidió print.
  def create_split(total_cajas)
    attrs = paquete_params.except(:cantidad_paquetes, :numero_caja).merge(
      estado: "empacado",
      user: Current.user
    )
    paquetes = Paquete.crear_split!(attrs: attrs, total_cajas: total_cajas)
    @paquete = paquetes.first
    paquetes.each { |p| link_pre_alertas(p) }
    @paquetes_hoy = paquetes_hoy_count

    respond_to do |format|
      format.turbo_stream do
        events = paquetes.map do |p|
          "<div data-etiquetar-target='event' data-action='paquete-saved' " \
            "data-guia='#{p.guia}' data-print='#{params[:print]}' data-paquete-id='#{p.id}'></div>"
        end.join

        render turbo_stream: [
          turbo_stream.update("paquetes-counter", @paquetes_hoy.to_s),
          turbo_stream.prepend("flash-messages", partial: "shared/flash",
                               locals: { notice: "Tracking dividido en #{total_cajas} cajas: #{paquetes.map(&:guia).join(', ')}." }),
          turbo_stream.append("etiquetar-events", events)
        ]
      end
      format.html do
        redirect_to etiquetar_path, notice: "Tracking dividido en #{total_cajas} cajas."
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    @paquete = e.record
    render_create_error
  end

  def render_create_error
    @tipo_envios = TipoEnvio.activos.order(:nombre)
    @carriers = Carrier.where(activo: true).order(:nombre)
    @paquetes_hoy = paquetes_hoy_count
    flash.now[:alert] = "No se pudo guardar el paquete."
    render :index, status: :unprocessable_entity
  end

  def authorize_etiquetar
    require_role(:supervisor_miami, :digitador_miami)
  end

  def paquetes_hoy_count
    Paquete.where(user: Current.user)
      .where(fecha_recibido_miami: Time.current.beginning_of_day..Time.current.end_of_day)
      .count
  end

  def link_pre_alertas(paquete)
    linked = PreAlertaPaquete.link_tracking!(paquete.tracking, paquete)
    if linked > 0
      PreAlertaMailer.paquete_recibido(paquete.cliente, paquete).deliver_later
    end
  end

  def paquete_params
    params.require(:paquete).permit(
      :tracking, :tracking_secundario, :cliente_id, :tipo_envio_id, :peso,
      :alto, :largo, :ancho, :cantidad_productos, :cantidad_paquetes,
      :numero_caja, :descripcion, :remitente, :expedido_por, :proveedor,
      :notas_internas, :pre_alerta,
      :solicito_cambio_servicio, :retener_miami
    )
  end

  # `pre_factura` es columna boolean Y a la vez el name de la asociación
  # belongs_to :pre_factura. Para evitar AssociationTypeMismatch al asignar
  # "0"/"1" desde el form, se escribe vía column accessor `paquete[:pre_factura]`.
  def pre_factura_flag_param
    return :missing unless params.dig(:paquete)&.key?(:pre_factura)

    ActiveModel::Type::Boolean.new.cast(params[:paquete][:pre_factura])
  end
end
