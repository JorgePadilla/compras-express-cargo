class PaquetesController < ApplicationController
  before_action :set_paquete, only: [ :show, :edit, :update, :warehouse_receipt, :etiqueta, :destroy, :eliminar_de_pre_alerta, :reimprimir_etiquetas, :mover_a_pre_alerta, :asignar_tercero, :quitar_tercero, :bajar_cajas ]
  before_action :authorize_tracking_actions, only: [ :check_tracking, :search ]
  before_action :authorize_edit, only: [ :edit, :update, :eliminar_de_pre_alerta, :mover_a_pre_alerta, :asignar_tercero, :quitar_tercero ]
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
    "created_at"       => "paquetes.created_at",
    "actualizado"      => "paquetes.updated_at"
  }.freeze

  # Por dónde arranca el listado cuando nadie eligió columna.
  #
  # Era `created_at`, y Yusef lo cazó el 2026-08-18: las dos cajas de un split
  # le salían **separadas**. La causa es de `PR-C7.20`: la Caja 1 **es** el
  # paquete que la pre-alerta dejó esperando, así que conserva la hora en que el
  # cliente lo anunció (11:11) mientras la Caja 2 nace al etiquetar (11:34).
  #
  #   > "Todas las actualizaciones tienen que ir con la última hora… si un
  #   >  paquete está disponible en Honduras, se tiene que actualizar con la
  #   >  hora que se marcó que estaba disponible."
  #
  # Con `updated_at` las cajas de un envío quedan juntas y lo que se acaba de
  # tocar sube al tope, que es cómo él lee la pantalla.
  ORDEN_POR_DEFECTO = "paquetes.updated_at".freeze

  EDIT_ROLES   = %w[admin supervisor_miami supervisor_prefactura].freeze
  DELETE_ROLES = %w[admin].freeze
  # PR-D7.b: cambios manuales de estado solo para roles con permiso de
  # edición. El resto ve el badge solo lectura y depende de los flujos
  # programáticos (manifiesto, entrega, pre-factura) para mover el
  # paquete por el pipeline. Por ahora alineado con EDIT_ROLES —
  # ampliar requiere también ampliar EDIT_ROLES.
  ESTADO_CHANGE_ROLES = EDIT_ROLES

  def index
    @paquetes = base_scope
                  .includes(:cliente, :tercero, :tipo_envio, :sucursal, :sucursal_destino, :manifiesto,
                            :pre_factura, :venta,
                            pre_alerta_paquetes: :pre_alerta)
    @paquetes = apply_filters(@paquetes)
    @paquetes = apply_sort(@paquetes)
    @paquetes = @paquetes.page(params[:page]).per(per_page_sanitized)
    @tipo_envios = TipoEnvio.activos.order(:nombre)
    @sucursales = Sucursal.activas.ordered
    @estados_paquete = Paquete::ESTADOS_SELECCIONABLES
    # Pre-fill para el input de autocomplete de Pre-Alerta cuando el filtro
    # viene en la URL. (El de Cliente fue removido — Yusef 2026-05-08:
    # reemplazado por "Búsqueda avanzada" + quick filters de codigo/nombre.)
    @pre_alerta_seleccionada = PreAlerta.find_by(id: params[:pre_alerta_id]) if params[:pre_alerta_id].present?
  end

  def show
    @edit_mode = params[:mode] == "edit"
    cargar_supervisores_cajas
    if @edit_mode
      @tipo_envios = TipoEnvio.activos.order(:nombre)
      @carriers = Carrier.where(activo: true).order(:nombre)
      @tarifas_recolecta = TarifaRecolecta.activas.ordered
      # Los motivos salen del controller, no de la vista. El bloque de retención
      # los consultaba adentro del ERB —la única de las cuatro pantallas que lo
      # hacía— y por eso el partial compartido no los podía recibir.
      @motivos_retencion = MotivoRetencion.activos.ordered
      # PR-5: cuando el digitador re-escanea un tracking existente desde
      # /etiquetar y elige "Cambio de Servicio", llegamos acá con
      # ?cambio_servicio=1. Pre-marcamos el flag en memoria (no se guarda
      # hasta que el operador confirme con Guardar) y exponemos un banner.
      if params[:cambio_servicio] == "1"
        @paquete.solicito_cambio_servicio = true
        @cambio_servicio_from_rescaneo = true
      end
    end
  end

  # Yusef 2026-05-08: el flow de edit ahora es inline en el show via
  # `?mode=edit`. Mantenemos la ruta para back-compat de links y la
  # redirigimos al show con el query param.
  def edit
    redirect_to paquete_path(@paquete, mode: "edit")
  end

  def update
    # PR-D7.b: gate de cambio de estado. Antes de aplicar attributes,
    # validamos quien y como puede tocar `estado`. Si bloqueamos,
    # rendereamos show con `@estado_transition_block` para que el modal
    # se abra automáticamente con motivo + acción alternativa.
    if (blocker = estado_transition_blocker(paquete_params))
      @estado_transition_block = blocker
      render_show_with_edit_assigns(status: blocker[:status])
      return
    end

    # PR-D7.d: cuando un retroceso ya fue confirmado por el supervisor,
    # limpiar fechas + FKs de los estados posteriores antes de tocar
    # attributes para que el paquete quede coherente con el nuevo estado.
    target_estado = paquete_params[:estado].to_s
    if target_estado.present? && target_estado != @paquete.estado &&
       Paquete.transicion_retroceso?(@paquete.estado, target_estado) &&
       params[:confirm_retroceso].to_s == "1"
      @paquete.apply_retroceso_cleanup!(target_estado)
    end

    # Si el operador cambió el cliente y hay PA vinculada, desvinculamos
    # automáticamente para mantener el invariante: paquete y su pre-alerta
    # tienen el mismo cliente. El operador puede re-vincular después con
    # "Asignar a Pre-Alerta" / "Mover a Pre-Alerta".
    cliente_change_unlinked_pa = nil
    new_cli_id = paquete_params[:cliente_id].to_i
    if new_cli_id.positive? && new_cli_id != @paquete.cliente_id && @paquete.pre_alerta_paquetes.any?
      cliente_change_unlinked_pa = @paquete.pre_alerta_paquetes.first.pre_alerta&.numero_documento
      @paquete.pre_alerta_paquetes.destroy_all
    end

    # PR-C6.7: cambiar la cantidad de cajas de un split crea o elimina las que
    # correspondan. Antes solo se actualizaba el número en cada fila y los
    # registros viejos quedaban dando vueltas — Yusef lo reprodujo bajando de
    # 3 a 2 y viendo que quedaban las 3.
    #
    # Va **antes** del save: si alguna caja a eliminar ya está cobrada, la
    # operación falla entera y no se guarda nada.
    nueva_cantidad = paquete_params[:cantidad_paquetes].to_i
    if ajusta_cajas?(nueva_cantidad)
      begin
        Paquete.ajustar_split!(@paquete, nueva_cantidad)
        @paquete.reload
      rescue Paquete::CajaNoEliminable => e
        flash.now[:alert] = e.message
        render_show_with_edit_assigns(status: :unprocessable_entity)
        return
      end
    end

    @paquete.assign_attributes(paquete_params)
    # `paquete[:pre_factura]` es columna boolean; el accessor normal lo
    # interpreta como la asociación belongs_to :pre_factura. Lo escribimos
    # vía el column accessor `[]=` para evitar AssociationTypeMismatch.
    if (flag = pre_factura_flag_param) != :missing
      @paquete[:pre_factura] = flag
    end

    if @paquete.save
      # Persistir instrucciones de la pre-alerta si el operador las editó
      # desde el form del paquete. Va a la primera PAP vinculada (caso
      # normal: 1 paquete vive en 1 pre-alerta).
      if params[:paquete].key?(:pap_instrucciones) && (pap = @paquete.pre_alerta_paquetes.first)
        pap.update(instrucciones: params[:paquete][:pap_instrucciones].to_s.strip.presence)
      end

      msg = "Paquete actualizado exitosamente."
      if cliente_change_unlinked_pa
        msg += " Se desvinculó de pre-alerta #{cliente_change_unlinked_pa} por cambio de cliente — usá 'Asignar a Pre-Alerta' para re-vincular."
      end
      redirect_to @paquete, notice: msg
    else
      render_show_with_edit_assigns(status: :unprocessable_entity)
    end
  end

  # Warehouse Receipt — hoja carta con términos y condiciones, para el
  # expediente. NO es lo que se le pega a la caja.
  # El Warehouse Receipt: hoja carta con términos y condiciones, para el
  # expediente. NO es la etiqueta que se pega a la caja — esa es `#etiqueta`.
  #
  # PR-10.d.3: se llamaba `#label`. El nombre venía del legacy, cuando este
  # documento se usaba como si fuera la etiqueta — que es justo lo que Yusef
  # reportó: "aquí está tirando el warehouse, no la etiqueta".
  def warehouse_receipt
    render layout: "print"
  end

  # PR-10.d: la etiqueta física que se pega a la caja. Dymo 2.25 × 1.25 in,
  # una por paquete. Hasta ahora `label` imprimía el Warehouse Receipt en
  # carta y se usaba como si fuera la etiqueta — Yusef: "aquí está tirando el
  # warehouse, no la etiqueta".
  #
  # Con ?hermanas=1 imprime las N cajas del mismo tracking de una vez
  # ("si el tracking se divide en 5 paquetes es una para cada una").
  def etiqueta
    # Quiénes son las hermanas lo decide **el modelo**, no esta acción. Acá había
    # una segunda consulta escrita a mano y por eso las etiquetas y el Warehouse
    # Receipt podían discrepar: el WR sí pasaba por `paquetes_hermanos`.
    @paquetes = if params[:hermanas] == "1" && @paquete.dividido?
      Paquete.where(id: [ @paquete.id, *@paquete.paquetes_hermanos.ids ])
             .includes(:cliente, :tercero, :tipo_envio, :sucursal, :user)
             .order(:numero_caja, :id)
    else
      [ @paquete ]
    end

    # Yusef: *"si después de imprimir la etiqueta, te tire automáticamente el
    # Recibo de Bodega"*. /entrega_personal abría dos ventanas y **Chrome
    # bloquea la segunda**: un gesto del usuario alcanza para un solo popup.
    # Ahora se abre una sola y, al terminar de imprimir, esa misma se va al
    # Warehouse Receipt en vez de cerrarse.
    #
    # La URL la arma el servidor a propósito: un parámetro con la dirección de
    # destino sería un redirect abierto servido desde nuestro propio dominio.
    @despues_de_imprimir = warehouse_receipt_paquete_path(@paquete) if params[:wr] == "1"

    render layout: "etiqueta"
  end

  # PR-D4.a: desvincula este paquete de TODAS sus pre-alertas (PreAlertaPaquete
  # join). NO destruye el paquete. Yusef: "esto se hace cuando el paquete lo
  # agregaron a una pre-alerta equivocada y necesitamos reasignarlo al cliente
  # correcto".
  def eliminar_de_pre_alerta
    count = @paquete.pre_alerta_paquetes.count
    if count.zero?
      redirect_to @paquete, alert: "Este paquete no está vinculado a ninguna pre-alerta."
      return
    end
    @paquete.pre_alerta_paquetes.destroy_all
    redirect_to @paquete, notice: "Paquete desvinculado de #{count} pre-alerta(s). Listo para reasignar."
  end

  # PR-D4.a.2: mueve este paquete a una pre-alerta existente. Yusef:
  # "se permite mover a pre-alerta de cualquier cliente (caso típico:
  # corregir asignación equivocada)". Borra los join existentes con
  # otras PAs y crea un nuevo PreAlertaPaquete vinculado a la PA destino.
  def mover_a_pre_alerta
    pa = PreAlerta.activas.find_by(id: params[:pre_alerta_id])
    if pa.nil?
      redirect_to @paquete, alert: "Pre-alerta no encontrada o anulada."
      return
    end

    PreAlertaPaquete.transaction do
      @paquete.pre_alerta_paquetes.destroy_all
      PreAlertaPaquete.create!(
        pre_alerta: pa,
        paquete: @paquete,
        tracking: @paquete.tracking,
        descripcion: @paquete.descripcion,
        fecha: Date.current
      )
      # Yusef: la fecha de pre-alerta debe reflejar la última transacción,
      # no la original. Actualizamos fecha + user explícitamente porque el
      # estado del paquete no cambia y el callback no dispara.
      @paquete.update!(
        fecha_pre_alerta: Time.current,
        fecha_pre_alerta_by_user_id: Current.user&.id
      )
    end

    redirect_to @paquete, notice: "Paquete movido a pre-alerta #{pa.numero_documento} (#{pa.cliente.codigo})."
  end

  # Asigna (o cambia) el Tercero — cliente final cuando CEC le maneja la
  # carga a una empresa pequeña con su propio cliente. Reemplazo del flow
  # "Asignar → edit mode" que confundía a los operadores.
  def asignar_tercero
    cliente = Cliente.activos.find_by(id: params[:tercero_id])
    if cliente.nil?
      redirect_to @paquete, alert: "Cliente no encontrado."
      return
    end
    if cliente.id == @paquete.cliente_id
      redirect_to @paquete, alert: "El tercero no puede ser el mismo cliente dueño del paquete."
      return
    end
    @paquete.update!(tercero: cliente)
    redirect_to @paquete, notice: "Tercero asignado: #{cliente.codigo} — #{cliente.nombre_completo}."
  end

  # PR-C6.42 · RP-18: un supervisor destraba con su PIN un split que quedó con
  # cajas de más. Yusef: "le pusieron 2 y al final es un paquete, y cuando van
  # a entregar, el sistema no va a querer entregar porque decía que eran dos".
  #
  # No lleva `authorize_edit`: igual que el "quitar cobro" de /etiquetar, el que
  # está en la pantalla es el operario y el supervisor es quien teclea el PIN al
  # lado. La autorización de verdad la hace `BajarCajasConPin`.
  def bajar_cajas
    quedan = BajarCajasConPin.new(
      paquete: @paquete,
      cantidad: params[:cantidad],
      supervisor: User.find_by(id: params[:supervisor_id]),
      pin: params[:pin],
      motivo: params[:motivo]
    ).call

    # Si el supervisor estaba parado justo en una de las cajas que se fueron,
    # `@paquete` ya no existe — mandarlo ahí sería un 404 después de una
    # operación exitosa.
    destino = quedan.find { |c| c.id == @paquete.id } || quedan.first
    redirect_to destino, notice: "Quedaron #{quedan.size} caja(s) en #{@paquete.tracking}."
  rescue BajarCajasConPin::NoPermitido, BajarCajasConPin::PinInvalido,
         BajarCajasConPin::YaFacturado, BajarCajasConPin::NadaQueBajar => e
    redirect_to @paquete, alert: e.message
  end

  def quitar_tercero
    if @paquete.tercero_id.nil?
      redirect_to @paquete, alert: "Este paquete no tiene tercero asignado."
      return
    end
    @paquete.update!(tercero: nil)
    redirect_to @paquete, notice: "Tercero removido del paquete."
  end

  # PR-D4.a: re-imprime etiquetas Miami. Para paquetes divididos (split en
  # varias cajas) muestra modal con checkboxes por caja. Para paquetes
  # individuales abre directamente la etiqueta. Yusef pidió que las cajas
  # hermanas estén preseleccionadas por default.
  def reimprimir_etiquetas
    if @paquete.dividido?
      @hermanas = @paquete.paquetes_hermanos.order(:numero_caja).to_a + [ @paquete ]
      @hermanas.sort_by!(&:numero_caja)
      render layout: false # modal partial
    else
      # PR-10.d.3: iba al Warehouse Receipt. Esta acción se llama
      # "reimprimir_etiquetas" y sacaba la hoja carta.
      redirect_to etiqueta_paquete_path(@paquete)
    end
  end

  # PR-D4.review v2: imprime varias etiquetas en UNA sola pestaña con
  # saltos de página. Reemplaza el flow de N pop-ups (que dependía del
  # browser autorizar pop-ups). El usuario elige las cajas con checkboxes
  # en `reimprimir_etiquetas` y submitea acá; auto-trigger window.print().
  def etiquetas_combinadas
    ids = Array(params[:paquete_ids]).reject(&:blank?).map(&:to_i)
    if ids.empty?
      redirect_to paquetes_path, alert: "Selecciona al menos una caja para imprimir."
      return
    end
    # PR-10.d.3: las asociaciones son las de la etiqueta, no las del Warehouse
    # Receipt — esto renderizaba warehouse receipts en carta.
    @paquetes = Paquete.where(id: ids)
                       .includes(:cliente, :tercero, :sucursal, :tipo_envio, :proveedor, :user)
                       .order(:numero_caja, :id)
    if @paquetes.empty?
      redirect_to paquetes_path, alert: "No se encontraron paquetes con los IDs solicitados."
      return
    end
    render layout: "etiqueta"
  end

  def destroy
    blockers = paquete_destroy_blockers(@paquete)
    if blockers.any?
      redirect_to @paquete, alert: "No se puede eliminar: #{blockers.to_sentence}."
      return
    end

    begin
      @paquete.destroy!
      redirect_to paquetes_path, notice: "Paquete #{@paquete.tracking} eliminado."
    rescue ActiveRecord::InvalidForeignKey
      redirect_to @paquete, alert: "No se puede eliminar: el paquete tiene dependencias activas en la base de datos."
    rescue ActiveRecord::RecordNotDestroyed => e
      messages = e.record.errors.full_messages
      msg = messages.any? ? messages.to_sentence : "tiene relaciones que no se pueden eliminar"
      redirect_to @paquete, alert: "No se puede eliminar: #{msg}."
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

  # Imprime los paquetes seleccionados via checkbox bulk. Renderiza HTML
  # con layout "print" (sin chrome) que auto-dispara window.print() — el
  # usuario ve el diálogo de impresión nativo del navegador en vez de
  # descargar un PDF. Yusef 2026-05-08: F4 debe abrir preview, no descarga.
  def bulk_print
    ids = Array(params[:paquete_ids]).reject(&:blank?)
    if ids.empty?
      redirect_to paquetes_path, alert: "Selecciona al menos un paquete."
      return
    end

    @paquetes = Paquete.where(id: ids).includes(:cliente, :tipo_envio, :sucursal).order(:numero_caja, :id)
    render :bulk_print, layout: "print"
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
    tracking = params[:tracking].to_s
    # PR-C6.21: antes era `where(tracking: tracking)` — exacto y case-sensitive
    # sobre una sola columna. Ahora entra por la escalera del modelo, que
    # además cubre el secundario y el código largo que escupe la pistola.
    # PR-C6.44: `excluir_paquete_id` deja que una fila pregunte sin avisarse a
    # sí misma. Cada `PreAlertaPaquete` materializa un Paquete en estado
    # `pre_alerta`, así que en el editor de pre-alertas tocar el propio tracking
    # encontraba el propio paquete y avisaba "ya está en el sistema".
    #
    # /etiquetar nunca manda el parámetro, así que la pistola de Miami se
    # comporta exactamente igual que antes.
    candidatos = Paquete.buscar_escaneado(tracking)
    if params[:excluir_paquete_id].present?
      candidatos = candidatos.where.not(id: params[:excluir_paquete_id])
    end
    paquete = candidatos.order(created_at: :desc).first

    # PR-2: detectar match con pre-alerta. Caso (a): el paquete ya existe en
    # estado `pre_alerta_estado` (lo creó PreAlertaPaquete#crear_paquete_esperado).
    # Caso (b): no hay paquete pero sí hay un PAP sin vincular con este tracking.
    pre_alerta_match_info = detect_pre_alerta_match(tracking, paquete)

    if paquete
      # PR-C6.21: el duplicado se calcula sobre el tracking **guardado**, no
      # sobre lo que entró por la pistola. Si el match vino por sufijo (USPS)
      # o por el secundario, lo escaneado no es el tracking del paquete, y
      # sufijar eso generaría un duplicado con un tracking que no existe.
      tracking_base = paquete.tracking
      next_suffix = Paquete.next_duplicate_suffix(tracking_base)

      render json: {
        exists: true,
        terminal: paquete.estado_terminal?,
        guia: ERB::Util.html_escape(paquete.guia),
        estado: ERB::Util.html_escape(paquete.estado),
        cliente: ERB::Util.html_escape(paquete.cliente.nombre_completo),
        fecha: paquete.fecha_recibido_miami&.strftime("%d/%m/%Y"),
        count: Paquete.where(tracking: tracking_base).count,
        # PR-10.c: Yusef sobre el modal de tracking repetido — "aquí solo
        # agregarle el contenido... el contenido y el tipo de servicio, esas
        # son las dos cosas que más te faltan ahí". El numero_recepcion ya se
        # tenía a mano y tampoco se estaba mostrando.
        descripcion: ERB::Util.html_escape(paquete.descripcion.to_s.truncate(80)),
        tipo_envio: ERB::Util.html_escape(paquete.tipo_envio&.nombre.to_s),
        numero_recepcion: ERB::Util.html_escape(paquete.numero_recepcion.to_s),
        # Datos para el flow de duplicado (Yusef 2026-04-25):
        # - existing_paquete_id: para "Es actualización" → cargar edit del original.
        # - tracking_base + next_suffix → para "Es duplicado real" → tracking nuevo.
        # - next_suffix nil cuando se agotó A-Z (intervención manual).
        existing_paquete_id: paquete.id,
        edit_url: edit_paquete_path(paquete),
        tracking_base: tracking_base,
        next_suffix: next_suffix,
        next_tracking: next_suffix ? "#{tracking_base}#{next_suffix}" : nil,
        **pre_alerta_match_info
      }
    else
      render json: { exists: false, **pre_alerta_match_info }
    end
  end

  # PR-2: helper que devuelve `pre_alerta_match: true` cuando este tracking
  # tiene una pre-alerta esperándolo. Frontend usa este flag para disparar
  # el sonido `notify` y mostrar un banner verde en vez del modal de duplicado.
  def detect_pre_alerta_match(tracking, paquete)
    return { pre_alerta_match: false } if tracking.blank?

    # PR-C6.21: por la misma escalera que el paquete. Antes era solo el match
    # exacto en mayúsculas, así que el código largo de USPS encontraba el
    # paquete y perdía su pre-alerta.
    pap_query = PreAlertaPaquete.sin_vincular.buscar_escaneado(tracking)

    pap = pap_query.includes(:pre_alerta).first
    # El renglón casi nunca está `sin_vincular`: `crear_paquete_esperado` le puso
    # `paquete_id` al materializar el esperado. Así que sin este segundo intento
    # `pap` queda en nil y con él se van **las instrucciones que escribió el
    # cliente** — que es justo lo que hay que mostrarle al que recibe.
    pap ||= PreAlertaPaquete.includes(:pre_alerta).find_by(paquete_id: paquete.id) if paquete
    pa = pap&.pre_alerta

    if pa.present?
      cli = pa.cliente
      {
        pre_alerta_match: true,
        pre_alerta_numero: ERB::Util.html_escape(pa.numero_documento.to_s),
        pre_alerta_cliente: ERB::Util.html_escape(cli&.nombre_completo.to_s),
        pre_alerta_descripcion: ERB::Util.html_escape((pap&.descripcion || paquete&.descripcion).to_s),
        # Fix auto-fill cliente: el frontend usa estos campos para auto-rellenar
        # el input "Cliente" y dejarlo en read-only (no permitir cambio al
        # operador, evita errores de tipear código equivocado).
        cliente_id: cli&.id,
        cliente_codigo: ERB::Util.html_escape(cli&.codigo.to_s),
        cliente_nombre: ERB::Util.html_escape(cli&.nombre_completo.to_s),
        cliente_notas_miami: ERB::Util.html_escape(cli&.notas_miami.to_s),
        # PR: a qué sucursal retira este cliente. Faltaba, y por eso al escanear
        # un tracking con pre-alerta **no salía el aviso de sucursal** — Yusef,
        # dos veces: "no me da la información de que es de Sucursal de
        # Tegucigalpa". Las notas del cliente sí venían: se agregó una y se
        # olvidó la otra. Misma llave que usa `/clientes/buscar`.
        cliente_sucursal_retiro: ERB::Util.html_escape(cli&.sucursal_retiro_nombre.to_s),
        # PR-C6.9: el tipo de envío que el cliente pidió en su pre-alerta. Si
        # no coincide con el de la sesión de etiquetado, el front avisa antes
        # de que el operario siga escribiendo — y el servidor lo rechaza igual.
        pre_alerta_tipo_envio_id: pa.tipo_envio_id,
        pre_alerta_tipo_envio: ERB::Util.html_escape(pa.tipo_envio&.nombre.to_s),
        # La retención que viene anunciada. Sin esto el formulario arrancaba con
        # el checkbox desmarcado, y un checkbox desmarcado manda `"0"`: el
        # escaneo **apagaba** la bandera que la pre-alerta acababa de traer, y
        # con ella los motivos. O sea que lo que Yusef pidió el 17-ago llegaba al
        # paquete esperado y se borraba en el momento de recibirlo.
        retener_miami: pap&.retener_miami? || paquete&.retener_miami? || false,
        motivo_retencion_ids: paquete&.motivo_retencion_ids || [],
        motivo_retencion_nombres: paquete&.motivos_retencion&.map { |m| ERB::Util.html_escape(m.nombre) } || [],
        notas_retencion: ERB::Util.html_escape(paquete&.notas_retencion.to_s),
        # Lo que el que recibe **tiene que ver antes de guardar**, no al costado.
        #
        # Yusef, 2026-08-19, señalando la franja: *"estas informaciones ellos no
        # las leen. Esto no lo van a leer, olvídate"* · *"no te voy a mentir,
        # Jorge: a puro huevos leen esto"*. Digitan de 500 a 1.000 paquetes al
        # día mirando la pistola, no la pantalla.
        tareas: tareas_del_cliente(cli),
        notas: notas_para_el_modal(pa, pap)
      }
    else
      { pre_alerta_match: false }
    end
  end
  # Las tareas abiertas del cliente, para el modal. Mismo criterio que la franja
  # de contexto: abiertas y visibles para quien está recibiendo.
  def tareas_del_cliente(cliente)
    return [] if cliente.nil?

    Tarea.abiertas
         .para_cliente(cliente.id)
         .visibles_para(Current.user)
         .order(created_at: :asc)
         .limit(5)
         .map do |t|
      { id: t.id, titulo: ERB::Util.html_escape(t.titulo.to_s),
        url: completar_tarea_path(t) }
    end
  end

  # Las notas que escribió el cliente sobre este envío.
  #
  # Van las dos: las `instrucciones` de **este** renglón y las `notas_grupo` de
  # la pre-alerta, que aplican a todo el envío. Yusef: *"aquí están las notas del
  # grupo y no sale… y el grupo sí tiene notas"*.
  def notas_para_el_modal(pre_alerta, pap)
    notas = []
    if pap&.instrucciones.present?
      notas << { titulo: "Instrucción del paquete",
                 texto: ERB::Util.html_escape(pap.instrucciones) }
    end
    if pre_alerta&.notas_grupo.present?
      notas << { titulo: "Nota del grupo",
                 texto: ERB::Util.html_escape(pre_alerta.notas_grupo) }
    end
    notas
  end
  private :tareas_del_cliente, :notas_para_el_modal

  private :detect_pre_alerta_match

  public

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

  private  # Genera el XLSX via Axlsx::Package directo (sin template) y lo manda
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
          p.numero_recepcion_visible || "—",
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
    # PR-D2: motivos_retencion para los badges en show/edit.
    # PR-D3.a: proveedor para evitar query extra al renderizar el detalle.
    # PR-6b: prepagado_miami_* para evitar 2 queries extras en show cuando
    # el banner verde de "PREPAGADO EN MIAMI" aparece (gemini-review #191).
    @paquete = Paquete.includes(
      :motivos_retencion, :proveedor, :tercero,
      :prepagado_miami_sucursal, :prepagado_miami_by_user
    ).find(params[:id])
  end

  def authorize_tracking_actions
    require_role(:supervisor_miami, :digitador_miami, :supervisor_prefactura, :supervisor_caja, :cajero)
  end

  def authorize_edit
    return if Current.user&.admin?
    return if EDIT_ROLES.include?(Current.user&.rol)
    redirect_to paquetes_path,
                alert: "No tienes permiso para editar paquetes. Solo admin, supervisor Miami o supervisor Pre-factura."
  end

  # PR-D7.b: decide si la transición de estado debe bloquearse antes de
  # tocar el paquete. Retorna nil cuando OK; un hash describiendo el
  # bloqueo (motivo + datos para el modal) cuando hay que cortar.
  def estado_transition_blocker(attrs)
    return nil unless attrs.key?(:estado)
    target = attrs[:estado].to_s
    return nil if target.blank?
    actual = @paquete.estado.to_s
    return nil if target == actual

    unless Current.user&.admin? || ESTADO_CHANGE_ROLES.include?(Current.user&.rol.to_s)
      return {
        motivo:   :rol,
        status:   :forbidden,
        actual:   actual,
        objetivo: target
      }
    end

    if Paquete.transicion_retroceso?(actual, target) &&
       params[:confirm_retroceso].to_s != "1"
      return {
        motivo:   :retroceso,
        status:   :unprocessable_entity,
        actual:   actual,
        objetivo: target,
        pasos:    Paquete.transicion_pasos_atras(actual, target)
      }
    end

    nil
  end

  # ¿El form está pidiendo cambiar la cantidad de cajas de verdad?
  #
  # Solo aplica a paquetes que YA son un split o que pasan a serlo. Un paquete
  # suelto que se edita sin tocar el campo no debe entrar acá — y menos uno
  # que llega con `cantidad_paquetes` en blanco, que es el default de muchos
  # formularios.
  def ajusta_cajas?(nueva_cantidad)
    return false unless paquete_params.key?(:cantidad_paquetes)
    return false if nueva_cantidad < 1

    actual = @paquete.cantidad_paquetes.to_i
    return false if nueva_cantidad == actual

    # Pasar de 1 a N sobre un paquete que nunca fue split lo convierte en uno;
    # `ajustar_split!` lo maneja creando las cajas que faltan.
    actual > 1 || nueva_cantidad > 1
  end

  def render_show_with_edit_assigns(status:)
    @edit_mode = true
    @tipo_envios = TipoEnvio.activos.order(:nombre)
    @carriers = Carrier.where(activo: true).order(:nombre)
    @tarifas_recolecta = TarifaRecolecta.activas.ordered
    @motivos_retencion = MotivoRetencion.activos.ordered
    cargar_supervisores_cajas
    render :show, status: status
  end

  # PR-C6.42: quién puede destrabar un split con cajas de más.
  #
  # Va en un método porque el `show` se renderiza por DOS caminos: la acción
  # `#show` y el re-render de `#update` cuando algo falla. Justamente por ese
  # segundo camino se llega acá con "no se puede bajar a N cajas" — o sea, el
  # momento exacto en que el operario necesita el botón.
  def cargar_supervisores_cajas
    @supervisores_cajas = User.activos.where(rol: BajarCajasConPin::ROLES)
                              .where.not(pin_digest: nil).order(:nombre)
  end

  def authorize_delete
    return if Current.user&.admin?
    return if DELETE_ROLES.include?(Current.user&.rol)
    redirect_to paquetes_path,
                alert: "No tienes permiso para eliminar paquetes. Solo administradores."
  end

  # Devuelve los motivos especificos por los cuales el paquete no puede
  # eliminarse (FK activas hacia documentos contables / logisticos).
  def paquete_destroy_blockers(paquete)
    blockers = []
    blockers << "tiene una pre-factura asociada (#{paquete.pre_factura.numero})" if paquete.pre_factura_id
    blockers << "tiene una venta facturada (#{paquete.venta.numero})" if paquete.venta_id
    blockers << "esta asignado a una entrega (#{paquete.entrega.numero})" if paquete.entrega_id
    blockers << "esta en un manifiesto (#{paquete.manifiesto.numero})" if paquete.manifiesto_id
    blockers
  end

  # Direccion del sort: solo aceptamos exactamente "asc" o "desc". Cualquier
  # otro valor (incluyendo strings con espacios, SQL fragments, nil) cae al
  # default "desc".
  SORT_DIRECTIONS = %w[asc desc].freeze

  def apply_sort(scope)
    sort_param = params[:sort].to_s
    user_picked_sort = SORTABLE_COLUMNS.key?(sort_param)
    column = user_picked_sort ? SORTABLE_COLUMNS[sort_param] : ORDEN_POR_DEFECTO

    dir = params[:dir].to_s.downcase
    direction = SORT_DIRECTIONS.include?(dir) ? dir : "desc"

    # Solo agregamos LEFT JOIN si el usuario realmente eligio una columna
    # de relacion. El sort default (created_at) no requiere joins extra.
    # Esto evita queries con joins innecesarios cuando se pagina sin sort.
    if user_picked_sort
      if column.start_with?("clientes.")
        scope = scope.left_joins(:cliente)
      elsif column.start_with?("tipo_envios.")
        scope = scope.left_joins(:tipo_envio)
      end
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

    scope = scope.by_cliente_codigo(params[:cliente_codigo]) if params[:cliente_codigo].present?
    scope = scope.by_cliente_nombre(params[:cliente_nombre]) if params[:cliente_nombre].present?
    scope = scope.busqueda_avanzada(params[:busqueda_avanzada]) if params[:busqueda_avanzada].present?
    scope = scope.by_pre_alerta(params[:pre_alerta_id]) if params[:pre_alerta_id].present?

    if params[:fecha_desde].present? && (fecha_desde = Date.parse(params[:fecha_desde]) rescue nil)
      scope = scope.where(fecha_recibido_miami: fecha_desde...)
    end
    if params[:fecha_hasta].present? && (fecha_hasta = Date.parse(params[:fecha_hasta]) rescue nil)
      scope = scope.where(fecha_recibido_miami: ...fecha_hasta.end_of_day)
    end

    # Quick toggles
    scope = scope.where(estado: "facturado") if params[:solo_facturados] == "1"
    # incluir_facturados (PR-D4 review): el default EXCLUYE facturados
    # (operadores ven solo trabajo activo). El toggle marcado los incluye.
    # `solo_facturados=1` y `solo_anulados=1` ya tienen su propio scope —
    # en esos casos no aplicamos la exclusión.
    unless params[:incluir_facturados] == "1" || params[:solo_facturados] == "1" || params[:solo_anulados] == "1"
      scope = scope.where.not(estado: "facturado")
    end
    scope = scope.where(pre_alerta: false) if params[:sin_prealerta] == "1"
    scope = scope.where(estado: "anulado") if params[:solo_anulados] == "1"
    scope = scope.where(pre_factura: true) if params[:solo_prefactura] == "1"
    scope
  end

  def paquete_params
    params.require(:paquete).permit(
      :tracking, :tracking_secundario, :cliente_id, :tipo_envio_id, :estado, :peso,
      :alto, :largo, :ancho, :cantidad_productos, :cantidad_paquetes,
      :numero_caja, :descripcion, :remitente, :driver, :expedido_por, :proveedor, :proveedor_id,
      :tercero_id, :tercero_nombre,
      :notas_internas, :notas_al_cliente, :notas_consolidacion, :notas_retencion,
      :pre_alerta,
      :solicito_cambio_servicio, :retener_miami,
      :recolecta_solicitada, :recolecta_monto, :recolecta_moneda, :tarifa_recolecta_id,
      # PR-D7.m: fechas editables manualmente (admin/supervisor). El gate
      # de permisos lo hace `authorize_edit` antes; el callback del modelo
      # `track_fecha_by_user_on_manual_edit` se encarga de _by_user_id.
      :fecha_solicito_recolecta, :fecha_pre_alerta, :fecha_recibido_miami,
      :fecha_empacado, :fecha_enviado, :fecha_aduana, :fecha_consolidando,
      :fecha_disponible, :fecha_posible_entrega, :fecha_en_reparto, :fecha_entregado,
      # Reasignación de manifiesto desde el form. El callback
      # `sync_dates_from_manifiesto` se encarga de actualizar las fechas.
      :manifiesto_id,
      motivo_retencion_ids: []
    )
  end

  # Devuelve true/false casteado, o `:missing` si el form no envió el campo.
  # Necesario porque `pre_factura` es columna boolean Y a la vez el name de
  # un belongs_to (la asociación gana al setter normal).
  def pre_factura_flag_param
    return :missing unless params.dig(:paquete)&.key?(:pre_factura)

    ActiveModel::Type::Boolean.new.cast(params[:paquete][:pre_factura])
  end
end
