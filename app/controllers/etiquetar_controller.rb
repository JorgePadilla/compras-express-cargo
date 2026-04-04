class EtiquetarController < ApplicationController
  before_action :authorize_etiquetar

  def index
    @paquete = Paquete.new
    @paquetes_hoy = Paquete.where(user: Current.user)
      .where(fecha_recibido_miami: Time.current.beginning_of_day..Time.current.end_of_day)
      .count
    @tipo_envios = TipoEnvio.activos.order(:nombre)
    @carriers = Carrier.where(activo: true).order(:nombre)
  end

  def create
    @paquete = Paquete.new(paquete_params)
    @paquete.estado = "etiquetado"
    @paquete.user = Current.user

    if @paquete.save
      @paquetes_hoy = Paquete.where(user: Current.user)
        .where(fecha_recibido_miami: Time.current.beginning_of_day..Time.current.end_of_day)
        .count

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
      @tipo_envios = TipoEnvio.activos.order(:nombre)
      @carriers = Carrier.where(activo: true).order(:nombre)
      @paquetes_hoy = Paquete.where(user: Current.user)
        .where(fecha_recibido_miami: Time.current.beginning_of_day..Time.current.end_of_day)
        .count
      render :index, status: :unprocessable_entity
    end
  end

  private

  def authorize_etiquetar
    require_role(:supervisor_miami, :digitador_miami)
  end

  def paquete_params
    params.require(:paquete).permit(
      :tracking, :cliente_id, :tipo_envio_id, :peso,
      :alto, :largo, :ancho, :cantidad_productos, :cantidad_paquetes,
      :numero_caja, :descripcion, :remitente, :expedido_por, :proveedor,
      :notas_internas, :pre_alerta, :pre_factura,
      :solicito_cambio_servicio, :retener_miami
    )
  end
end
