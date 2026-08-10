class EntregaPersonalController < ApplicationController
  # PR-C6.31: el partial de peso y medidas es el mismo que el de /etiquetar,
  # así que las filas por caja también tienen que leerse igual. Antes esta
  # pantalla las pintaba y después las tiraba: todas las cajas nacían con el
  # peso de arriba.
  include MedidasPorCaja

  before_action :authorize_entrega_personal

  # PR-6: flow separado para paquetes que llegan FÍSICAMENTE al mostrador
  # en Miami (sin tracking del courier). Sistema genera tracking
  # automático EP-YYYY-SUC-PROV-NNNNNN vía Paquete#generate_ep_tracking
  # callback que ya existe (PR-D3.b).

  def new
    @paquete = Paquete.new
    @paquetes_hoy = paquetes_ep_hoy_count
    @tipo_envios = TipoEnvio.activos.order(:nombre)
    @proveedores_ep = Proveedor.where(tipo: "entrega_personal").activos.ordered
    @sucursales_miami = Sucursal.activas.where(ubicacion: "miami").where.not(codigo_ep: nil).ordered
    @motivos_retencion = MotivoRetencion.activos.ordered
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
    @paquete = Paquete.new(paquete_params)
    apply_extra_params(@paquete)
    heredar_sucursal_de_retiro(@paquete)
    @paquete.estado = "recibido_miami"
    @paquete.user = Current.user

    if @paquete.save
      respond_saved([ @paquete ])
    else
      render_create_error
    end
  end

  def create_split(total_cajas)
    attrs = paquete_params.except(:cantidad_paquetes, :numero_caja).merge(
      estado: "recibido_miami",
      user: Current.user
    )
    paquetes = Paquete.crear_split!(attrs: attrs, total_cajas: total_cajas,
                                    por_caja: medidas_por_caja)
    paquetes.each do |p|
      apply_extra_params(p)
      heredar_sucursal_de_retiro(p)
      p.save!
    end
    respond_saved(paquetes)
  rescue ActiveRecord::RecordInvalid => e
    @paquete = e.record
    render_create_error
  end

  # PR-C6.37: donde retira el cliente. Ojo con el choque de nombres: en esta
  # pantalla `sucursal_id` es la de MIAMI donde se recibe (define el prefijo del
  # tracking EP), asi que la de retiro solo se pone si el form no mando una.
  def heredar_sucursal_de_retiro(paquete)
    paquete.sucursal ||= paquete.cliente&.sucursal_retiro
  end

  # `prepagado_miami` + sus columnas asociadas se asignan acá porque vienen
  # como flag + se traduce a múltiples columns (sucursal, user, timestamp).
  def apply_extra_params(paquete, save: false)
    if (prov_str = proveedor_string_param) != :missing
      paquete[:proveedor] = prov_str
    end
    if ActiveModel::Type::Boolean.new.cast(params.dig(:paquete, :prepagado_miami))
      paquete.prepagado_miami           = true
      paquete.prepagado_miami_sucursal  = paquete.sucursal
      paquete.prepagado_miami_by_user   = Current.user
      paquete.prepagado_miami_at        = Time.current
    end
    paquete.save! if save
  end

  def respond_saved(paquetes)
    @paquete = paquetes.first
    msg = paquetes.size > 1 ?
            "Entrega personal registrada — #{paquetes.size} cajas: #{paquetes.map(&:guia).join(', ')}" :
            "Entrega personal registrada — tracking #{@paquete.tracking}"

    respond_to do |format|
      format.turbo_stream do
        events = paquetes.map do |p|
          "<div data-entrega-personal-target='event' data-action='paquete-saved' " \
            "data-guia='#{p.guia}' data-print='#{params[:print]}' data-paquete-id='#{p.id}'></div>"
        end.join
        render turbo_stream: [
          turbo_stream.update("paquetes-counter", paquetes_ep_hoy_count.to_s),
          turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { notice: msg }),
          turbo_stream.append("entrega-personal-events", events)
        ]
      end
      format.html do
        redirect_to new_entrega_personal_path, notice: msg
      end
    end
  end

  def render_create_error
    @paquetes_hoy = paquetes_ep_hoy_count
    @tipo_envios = TipoEnvio.activos.order(:nombre)
    @proveedores_ep = Proveedor.where(tipo: "entrega_personal").activos.ordered
    # PR-9.b: faltaba `@sucursales_miami` — la vista hace `.any?` sobre él, así
    # que cualquier error de validación reventaba con un 500 en vez de mostrar
    # los errores al digitador.
    @sucursales_miami = Sucursal.activas.where(ubicacion: "miami").where.not(codigo_ep: nil).ordered
    @motivos_retencion = MotivoRetencion.activos.ordered
    flash.now[:alert] = "No se pudo registrar la entrega personal."
    render :new, status: :unprocessable_entity
  end

  def authorize_entrega_personal
    require_role(:supervisor_miami, :digitador_miami)
  end

  def paquetes_ep_hoy_count
    Paquete
      .joins(:proveedor)
      .where(proveedores: { tipo: "entrega_personal" })
      .where(user: Current.user)
      .where(created_at: Time.current.beginning_of_day..Time.current.end_of_day)
      .count
  end

  def paquete_params
    params.require(:paquete).permit(
      :cliente_id, :tipo_envio_id, :proveedor_id, :sucursal_id, :peso,
      :alto, :largo, :ancho, :cantidad_productos, :cantidad_paquetes,
      :numero_caja, :descripcion, :remitente, :driver,
      :notas_internas, :notas_retencion,
      :retener_miami,
      motivo_retencion_ids: []
    )
  end

  # `proveedor` string legacy choca con `belongs_to :proveedor` (mismo
  # patrón del bug PR fix #185 en EtiquetarController). Lo extraemos
  # aparte para asignar vía column accessor.
  def proveedor_string_param
    return :missing unless params.dig(:paquete)&.key?(:proveedor)

    params[:paquete][:proveedor].to_s
  end
end
