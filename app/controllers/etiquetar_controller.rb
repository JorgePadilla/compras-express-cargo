class EtiquetarController < ApplicationController
  before_action :authorize_etiquetar
  before_action :load_tipo_envio_sesion
  before_action :require_tipo_envio_sesion, only: :create

  def index
    @paquete = Paquete.new
    @paquetes_hoy = paquetes_hoy_count
    @tipo_envios = TipoEnvio.activos.order(:nombre)
    # Las que pueden emitir número de recepción. Si hay una sola, la vista no
    # pregunta nada y la manda en un hidden.
    @sucursales_recepcion = sucursales_recepcion_posibles
    @sucursal_recepcion_sugerida = @sucursal_recepcion_sesion || sucursal_recepcion_por_defecto
    @carriers = Carrier.where(activo: true).order(:nombre)
    @motivos_retencion = MotivoRetencion.activos.ordered
  end

  # El operario elige el tipo de envío que va a trabajar en este lote, y en
  # qué sucursal está recibiendo. Los dos quedan en session y aplican a cada
  # paquete que etiquete hasta finalizar.
  #
  # PR-C6.5: la sucursal de recepción es lo que le da número de recepción al
  # paquete. Antes `/etiquetar` no asignaba ninguna sucursal —ni una sola
  # mención en el controller ni en la vista— así que **ningún paquete
  # etiquetado tenía número**, y su etiqueta terminaba imprimiendo el tracking
  # en el código de barras. Yusef: "el código de barra que está aquí es el
  # warehouse, no es el tracking".
  #
  # Va en la sesión y no en el formulario porque no cambia paquete a paquete:
  # el que recibe está parado en un lugar. Yusef lo describió así — "está
  # alguien en Miami recibiendo, o en Panamá, o en China".
  def iniciar_sesion
    tipo = TipoEnvio.activos.find_by(id: params[:tipo_envio_id])
    return redirect_to(etiquetar_path, alert: "Seleccioná un tipo de envío válido.") if tipo.nil?

    sucursal = Sucursal.find_by(id: params[:sucursal_recepcion_id]) || sucursal_recepcion_por_defecto
    if sucursal.nil?
      return redirect_to etiquetar_path,
                         alert: "Seleccioná en qué sucursal estás recibiendo."
    end

    session[:etiquetar_tipo_envio_id] = tipo.id
    session[:etiquetar_sucursal_recepcion_id] = sucursal.id
    # Sin flash: el banner de sesión activa ya comunica el tipo elegido.
    redirect_to etiquetar_path
  end

  # Cierra el lote actual; la próxima visita vuelve a preguntar el tipo.
  def finalizar_sesion
    session.delete(:etiquetar_tipo_envio_id)
    session.delete(:etiquetar_sucursal_recepcion_id)
    redirect_to etiquetar_path, notice: "Sesión de etiquetado finalizada."
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
    # El tipo de envío lo manda la sesión de etiquetado, no el form.
    @paquete.tipo_envio_id = @tipo_envio_sesion.id
    # PR-C6.5: y la sucursal donde se está recibiendo, que es de donde sale el
    # número de recepción. Sin esto el paquete nace sin número y su etiqueta
    # imprime el tracking en el código de barras.
    @paquete.sucursal_recepcion = @sucursal_recepcion_sesion
    if (flag = pre_factura_flag_param) != :missing
      @paquete[:pre_factura] = flag
    end
    if (prov_str = proveedor_string_param) != :missing
      @paquete[:proveedor] = prov_str
    end

    if @paquete.save
      link_pre_alertas(@paquete)
      @paquetes_hoy = paquetes_hoy_count

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("paquetes-counter", @paquetes_hoy.to_s),
            turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { notice: "Paquete #{@paquete.tracking} guardado exitosamente." }),
            turbo_stream.append("etiquetar-events", "<div data-etiquetar-target='event' data-action='paquete-saved' data-guia='#{@paquete.guia}' data-print='#{params[:print]}' data-paquete-id='#{@paquete.id}'></div>")
          ]
        end
        format.html do
          redirect_to etiquetar_path, notice: "Paquete #{@paquete.tracking} guardado exitosamente."
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
      user: Current.user,
      tipo_envio_id: @tipo_envio_sesion.id,
      # Las N cajas comparten el número madre, y ese número sale de acá.
      sucursal_recepcion: @sucursal_recepcion_sesion
    )
    paquetes = Paquete.crear_split!(attrs: attrs, total_cajas: total_cajas)
    if (prov_str = proveedor_string_param) != :missing && prov_str.present?
      paquetes.each { |p| p.update_column(:proveedor, prov_str) }
    end
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
    # Las que pueden emitir número de recepción. Si hay una sola, la vista no
    # pregunta nada y la manda en un hidden.
    @sucursales_recepcion = sucursales_recepcion_posibles
    @sucursal_recepcion_sugerida = @sucursal_recepcion_sesion || sucursal_recepcion_por_defecto
    @carriers = Carrier.where(activo: true).order(:nombre)
    @motivos_retencion = MotivoRetencion.activos.ordered
    @paquetes_hoy = paquetes_hoy_count
    flash.now[:alert] = "No se pudo guardar el paquete."
    render :index, status: :unprocessable_entity
  end

  def authorize_etiquetar
    require_role(:supervisor_miami, :digitador_miami)
  end

  # Tipo de envío activo del lote (puede ser nil → la vista muestra el prompt).
  def load_tipo_envio_sesion
    @tipo_envio_sesion = TipoEnvio.activos.find_by(id: session[:etiquetar_tipo_envio_id])
    session.delete(:etiquetar_tipo_envio_id) if @tipo_envio_sesion.nil?

    @sucursal_recepcion_sesion = Sucursal.find_by(id: session[:etiquetar_sucursal_recepcion_id])
    # Sesiones abiertas antes de PR-C6.5 no traen sucursal. En vez de
    # obligarlos a cerrar y volver a abrir en medio de un lote, se cae al
    # default — que es la misma sucursal donde ya estaban recibiendo.
    @sucursal_recepcion_sesion ||= sucursal_recepcion_por_defecto if @tipo_envio_sesion
  end

  # Las sucursales que pueden emitir número de recepción — o sea, las que
  # tienen prefijo (`RMI`, `RZE`, `RHU`, `RSM`). Una sin prefijo no puede
  # numerar nada, así que ofrecerla sería ofrecer un paquete sin número.
  #
  # Se acotan a la ubicación del usuario: quien recibe está parado en un
  # lugar. Hoy `/etiquetar` es solo para Miami, así que queda una sola y la
  # vista no pregunta nada; el día que abran Panamá o China aparece el select
  # sin tocar código.
  def sucursales_recepcion_posibles
    scope = Sucursal.where.not(codigo_recepcion_prefix: [ nil, "" ])
    por_ubicacion = Current.user&.ubicacion.present? ? scope.where(ubicacion: Current.user.ubicacion) : scope
    # Si la ubicación del usuario no matchea ninguna, mejor ofrecer todas que
    # dejarlo sin poder abrir sesión.
    (por_ubicacion.any? ? por_ubicacion : scope).order(:id).to_a
  end

  # Dónde recibe este usuario, cuando no eligió explícitamente.
  def sucursal_recepcion_por_defecto
    sucursales_recepcion_posibles.first
  end

  # No se puede etiquetar sin un tipo de envío de sesión activo.
  def require_tipo_envio_sesion
    return if @tipo_envio_sesion

    redirect_to etiquetar_path, alert: "Iniciá una sesión de etiquetado primero."
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
    # tipo_envio_id NO se permite aquí: lo fija la sesión de etiquetado.
    params.require(:paquete).permit(
      :tracking, :tracking_secundario, :cliente_id, :tercero_id, :peso,
      :alto, :largo, :ancho, :cantidad_productos, :cantidad_paquetes,
      :numero_caja, :descripcion, :remitente, :expedido_por,
      :notas_internas, :notas_retencion, :pre_alerta,
      :solicito_cambio_servicio, :retener_miami,
      motivo_retencion_ids: []
    )
  end

  # `pre_factura` es columna boolean Y a la vez el name de la asociación
  # belongs_to :pre_factura. Para evitar AssociationTypeMismatch al asignar
  # "0"/"1" desde el form, se escribe vía column accessor `paquete[:pre_factura]`.
  def pre_factura_flag_param
    return :missing unless params.dig(:paquete)&.key?(:pre_factura)

    ActiveModel::Type::Boolean.new.cast(params[:paquete][:pre_factura])
  end

  # `proveedor` (string legacy) Y a la vez el name de la asociación
  # belongs_to :proveedor (PR-D3.a catálogo). Mismo conflicto que pre_factura:
  # asignar un string desde el form dispara AssociationTypeMismatch. Se escribe
  # vía column accessor `paquete[:proveedor]`. La asociación se usa solo cuando
  # hay un Proveedor del catálogo (via proveedor_id en otros flows).
  def proveedor_string_param
    return :missing unless params.dig(:paquete)&.key?(:proveedor)

    params[:paquete][:proveedor].to_s
  end
end
