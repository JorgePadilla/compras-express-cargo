class EtiquetarController < ApplicationController
  before_action :authorize_etiquetar
  before_action :load_tipo_envio_sesion
  before_action :require_tipo_envio_sesion, only: :create

  def index
    # PR-C6.10: `?paquete_id=` recarga el formulario con lo que el paquete ya
    # tiene, para actualizarlo acá mismo. Yusef: "me mandaste a editar y yo no
    # quiero editar mi paquete... que te cargue aquí la lista".
    @paquete = paquete_a_actualizar || Paquete.new
    @modo_actualizacion = @paquete.persisted?
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

  # Actualiza un paquete SIN salir de /etiquetar.
  #
  # La línea divisoria la definió Yusef y se respeta en el servidor:
  #
  #   > "Si ellos entran a actualizar acá es porque van a actualizar **datos
  #   >  del paquete**, de lo que ellos ingresan." · "Si van a actualizar un
  #   >  **estado** actual del paquete, eso sí lo van a tener que hacer en
  #   >  todos los paquetes."
  #
  # Por eso `paquete_params` no permite `estado` — y hay un test que lo fija.
  #
  # El tipo de envío **no** se pisa con el de la sesión al actualizar. Si el
  # paquete es CEM y el operario está en sesión CER, corregirle el peso no
  # puede convertirlo en CER. La sesión manda al crear; acá solo si pidió
  # cambio de servicio explícito.
  def update
    @paquete = Paquete.find(params[:id])
    @modo_actualizacion = true

    unless aplicar_cambio_servicio(@paquete)
      return render_create_error("Marcaste cambio de servicio: elegí a qué tipo de envío cambia.")
    end

    # La cantidad de cajas se delega al ajuste de split, que crea o elimina
    # las que correspondan (PR-C6.7) y bloquea si alguna ya se cobró.
    nueva_cantidad = paquete_params[:cantidad_paquetes].to_i
    if ajusta_cajas?(nueva_cantidad)
      begin
        Paquete.ajustar_split!(@paquete, nueva_cantidad)
        @paquete.reload
      rescue Paquete::CajaNoEliminable => e
        return render_create_error(e.message)
      end
    end

    @paquete.assign_attributes(paquete_params.except(:cantidad_paquetes))
    if (prov_str = proveedor_string_param) != :missing
      @paquete[:proveedor] = prov_str
    end

    if @paquete.save
      @paquetes_hoy = paquetes_hoy_count
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.prepend("flash-messages", partial: "shared/flash",
                                 locals: { notice: "Paquete #{@paquete.tracking} actualizado." }),
            turbo_stream.append("etiquetar-events",
                                "<div data-etiquetar-target='event' data-action='paquete-saved' " \
                                "data-guia='#{@paquete.guia}' data-print='#{params[:print]}' " \
                                "data-paquete-id='#{@paquete.id}'></div>")
          ]
        end
        format.html { redirect_to etiquetar_path, notice: "Paquete #{@paquete.tracking} actualizado." }
      end
    else
      render_create_error("No se pudo actualizar el paquete.")
    end
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
    # PR-C6.8: si marcó cambio de servicio, el destino pisa al de la sesión.
    # Antes el flag quedaba marcado y el tipo se quedaba en el de la sesión —
    # "cambio de servicio → CER a CKM no funciona".
    unless aplicar_cambio_servicio(@paquete)
      render_create_error("Marcaste cambio de servicio: elegí a qué tipo de envío cambia.")
      return
    end
    if (conflicto = conflicto_con_la_sesion(@paquete))
      render_create_error(conflicto)
      return
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
    # Mismo guard que el single: no se graban cajas bajo el tipo equivocado.
    if (conflicto = conflicto_con_la_sesion(Paquete.new(paquete_params)))
      @paquete = Paquete.new(paquete_params)
      return render_create_error(conflicto)
    end

    # El cambio de servicio aplica a las N cajas por igual: es el mismo
    # tracking, no se parte en dos servicios distintos.
    if ActiveModel::Type::Boolean.new.cast(paquete_params[:solicito_cambio_servicio])
      destino = TipoEnvio.activos.find_by(id: params.dig(:paquete, :tipo_envio_destino_id))
      unless destino
        @paquete = Paquete.new(paquete_params)
        return render_create_error("Marcaste cambio de servicio: elegí a qué tipo de envío cambia.")
      end
      attrs = attrs.merge(
        tipo_envio_id: destino.id,
        tipo_envio_anterior_id: @tipo_envio_sesion.id
      )
    end

    paquetes = Paquete.crear_split!(attrs: attrs, total_cajas: total_cajas,
                                    por_caja: medidas_por_caja)
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

  def render_create_error(mensaje = "No se pudo guardar el paquete.")
    @tipo_envios = TipoEnvio.activos.order(:nombre)
    # Las que pueden emitir número de recepción. Si hay una sola, la vista no
    # pregunta nada y la manda en un hidden.
    @sucursales_recepcion = sucursales_recepcion_posibles
    @sucursal_recepcion_sugerida = @sucursal_recepcion_sesion || sucursal_recepcion_por_defecto
    @carriers = Carrier.where(activo: true).order(:nombre)
    @motivos_retencion = MotivoRetencion.activos.ordered
    @paquetes_hoy = paquetes_hoy_count
    flash.now[:alert] = mensaje
    render :index, status: :unprocessable_entity
  end

  # Aplica el destino del cambio de servicio, si lo pidieron.
  #
  # El tipo de envío normalmente lo manda la sesión de etiquetado. El cambio
  # de servicio es la **excepción explícita**: el paquete sale de la sesión en
  # la que se está trabajando, y por eso se registra de dónde venía.
  #
  # Devuelve false si marcó el flag y no eligió destino, para que el caller
  # corte antes de guardar. **No** se usa `errors.add` acá: el `valid?` que
  # corre adentro de `save` limpia los errores, así que el paquete se
  # guardaría igual — a medias, con el flag prendido sobre el tipo viejo, que
  # es justo lo que pasaba antes.
  def aplicar_cambio_servicio(paquete)
    return true unless ActiveModel::Type::Boolean.new.cast(paquete_params[:solicito_cambio_servicio])

    destino = TipoEnvio.activos.find_by(id: params.dig(:paquete, :tipo_envio_destino_id))
    return false if destino.nil?

    paquete.aplicar_cambio_servicio(destino)
    true
  end

  # ¿Este paquete pertenece a otro tipo de envío que el de la sesión?
  #
  # Devuelve el mensaje de error, o nil si está todo bien.
  #
  # **Esto es la mitad que cobra bien.** El modal del front es la mitad
  # visible; sin el rechazo del servidor un paquete con pre-alerta CKM
  # escaneado en sesión CER **se guardaba como CER en silencio**, porque
  # `create_single` hace `tipo_envio_id = @tipo_envio_sesion.id` sin preguntar.
  #
  # Yusef lo consultó con Julián (Miami) por videollamada en la reunión y
  # quedaron en que no se puede guardar bajo el tipo equivocado:
  #
  #   > "No te va a permitir grabarlo. No vas a poder hacerlo... el chavo no
  #   >  hizo nada, no pudo hacer nada."
  #
  # El cambio de servicio (PR-C6.8) es la **excepción explícita**: ahí el
  # operario declaró que el paquete sale de la sesión, así que no hay
  # conflicto que reportar.
  def conflicto_con_la_sesion(paquete)
    return nil if paquete.solicito_cambio_servicio?

    tipo_pa = tipo_envio_de_la_pre_alerta(paquete.tracking)
    return nil if tipo_pa.nil?
    return nil if tipo_pa.id == @tipo_envio_sesion.id

    "Este paquete tiene pre-alerta de #{tipo_pa.nombre} y estás trabajando " \
    "#{@tipo_envio_sesion.nombre}. Finalizá la sesión y abrí una de " \
    "#{tipo_pa.nombre}, o marcá cambio de servicio."
  end

  # El tipo de envío que el cliente pidió en su pre-alerta, si hay una sin
  # vincular con este tracking.
  def tipo_envio_de_la_pre_alerta(tracking)
    return nil if tracking.blank?

    PreAlertaPaquete.sin_vincular
                    .where("UPPER(tracking) = ?", tracking.to_s.strip.upcase)
                    .includes(:pre_alerta)
                    .first&.pre_alerta&.tipo_envio
  end

  # Peso y medidas propios de cada caja, desde el modal de F9.
  #
  # PR-C6.17. Llegan como `paquete[cajas][1][peso]`. Solo se aceptan estos
  # cuatro campos: el resto del paquete es el mismo para todas las cajas — es
  # el mismo tracking, el mismo cliente y el mismo contenido; lo único que
  # cambia físicamente es cuánto pesa y mide cada bulto.
  CAMPOS_POR_CAJA = %w[peso alto largo ancho].freeze

  def medidas_por_caja
    crudo = params.dig(:paquete, :cajas)
    return {} if crudo.blank?

    crudo.to_unsafe_h.each_with_object({}) do |(indice, valores), acc|
      limpios = valores.slice(*CAMPOS_POR_CAJA).reject { |_k, v| v.to_s.strip.empty? }
      acc[indice.to_i] = limpios.symbolize_keys if limpios.any?
    end
  end

  # El paquete que se está actualizando, si vino por `?paquete_id=`.
  def paquete_a_actualizar
    return nil if params[:paquete_id].blank?

    Paquete.find_by(id: params[:paquete_id])
  end

  # ¿El form pide cambiar la cantidad de cajas de verdad? Mismo criterio que
  # `PaquetesController`: solo cuando ya es un split o pasa a serlo.
  def ajusta_cajas?(nueva_cantidad)
    return false unless paquete_params.key?(:cantidad_paquetes)
    return false if nueva_cantidad < 1

    actual = @paquete.cantidad_paquetes.to_i
    return false if nueva_cantidad == actual

    actual > 1 || nueva_cantidad > 1
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
      :tracking, :tracking_secundario, :cliente_id, :tercero_id, :tercero_nombre, :peso,
      :alto, :largo, :ancho, :cantidad_productos, :cantidad_paquetes,
      :numero_caja, :descripcion, :remitente, :expedido_por,
      :notas_internas, :notas_retencion,
      :solicito_cambio_servicio, :retener_miami,
      motivo_retencion_ids: []
    )
  end

  # PR-C6.11: `pre_factura_flag_param` vivía acá. Se fue con los checkboxes de
  # Pre-Alerta y Pre-Factura que Yusef mandó sacar de /etiquetar — "esto no
  # tiene nada que ver con ellos". Dejar el lector de un param que nadie manda
  # solo confunde al que venga después.
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
