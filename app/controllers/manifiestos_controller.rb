class ManifiestosController < ApplicationController
  # `buscar` (JSON) lo usan operadores que editan paquetes pero no
  # necesariamente tienen rol de Miami — se gatea via authorize_edit
  # del paquete antes de llegar acá.
  before_action :authorize_manifiestos, except: [ :buscar ]
  before_action :set_manifiesto, only: %i[show edit update add_paquete remove_paquete finalizar documento]

  def index
    @manifiestos = Manifiesto.activos.includes(:empresa_manifiesto).order(created_at: :desc)
    @manifiestos = @manifiestos.buscar(params[:q]) if params[:q].present?
    @manifiestos = @manifiestos.by_estado(params[:estado]) if params[:estado].present?
    @manifiestos = @manifiestos.page(params[:page]).per(per_page_sanitized)
  end

  def show
    # C21-04: los tamaños pre-definidos con los que se arma una casa.
    @tamanos = TamanoCaja.activos.ordered
    @paquetes = @manifiesto.paquetes.includes(:cliente, :sucursal, :sucursal_destino).order(:created_at)
  end

  def new
    @manifiesto = Manifiesto.new
    assigns_del_formulario
  end

  def create
    atributos = manifiesto_params
    @manifiesto = Manifiesto.new(atributos)
    @manifiesto.sucursal_origen_id = sucursal_origen_para(atributos)
    @manifiesto.user = Current.user

    if @manifiesto.save
      redirect_to @manifiesto, notice: "Manifiesto #{@manifiesto.numero} creado exitosamente."
    else
      assigns_del_formulario
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    assigns_del_formulario
  end

  def update
    unless @manifiesto.editable_por?(Current.user)
      redirect_to @manifiesto,
                  alert: "#{@manifiesto.numero} está finalizado: solo el supervisor de Miami puede reabrirlo."
      return
    end

    if @manifiesto.update(manifiesto_params)
      redirect_to @manifiesto, notice: "Manifiesto actualizado exitosamente."
    else
      assigns_del_formulario
      render :edit, status: :unprocessable_entity
    end
  end

  def add_paquete
    paquete = Paquete.find(params[:paquete_id])
    paquete.update!(manifiesto: @manifiesto)
    @manifiesto.recalculate_totals!
    respond_to_paquete_change("Paquete #{paquete.guia} agregado al manifiesto.")
  end

  def remove_paquete
    paquete = @manifiesto.paquetes.find(params[:paquete_id])
    # PR-C6.22: sacar del manifiesto devuelve a **recibido**, no a empacado.
    # Con el módulo de empaque todavía sin existir, nadie asigna `empacado`,
    # así que devolver ahí dejaba el paquete en un estado sin dueño: no lo
    # produce ninguna pantalla y no lo consume ningún flujo.
    paquete.update!(manifiesto: nil, estado: EtiquetarController::ESTADO_AL_ETIQUETAR)
    @manifiesto.recalculate_totals!
    respond_to_paquete_change("Paquete #{paquete.guia} removido del manifiesto.")
  end

  # C21-06 · «Solo Finalizar» y «Finalizar e Imprimir». Los paquetes de los
  # tipos seleccionados pasan a ENVIADO, uno por uno; los que tienen una tarea
  # abierta no pasan y salen listados, sin trabar a los demás — la misma forma
  # que `A7-05` eligió para la recepción parcial.
  def finalizar
    resultado = @manifiesto.finalizar!(user: Current.user)

    # C21-06 · Jorge, 2026-08-30: *"bloquear cierre"*. Un paquete trabado no
    # deja finalizar a ninguno — el manifiesto queda igual que estaba y hay que
    # resolver la tarea antes de volver a darle.
    if resultado.bloqueado?
      trabados = resultado.trabados.map { |paquete, motivo| "#{paquete.numero_recepcion_visible} (#{motivo})" }
      redirect_to @manifiesto,
                  alert: "No se finalizó #{@manifiesto.numero}: #{resultado.trabados.size} paquete(s) con tareas abiertas. #{trabados.join(' · ')}"
      return
    end

    aviso = "Manifiesto #{@manifiesto.numero} finalizado: #{resultado.enviados.size} paquete(s) a enviado."

    if params[:imprimir].present? && @manifiesto.cajas.any?
      redirect_to etiquetas_manifiesto_cajas_path(@manifiesto, print: true), notice: aviso
    else
      redirect_to @manifiesto, notice: aviso
    end
  rescue ArgumentError => e
    redirect_to @manifiesto, alert: e.message
  end

  # C21-09 · El manifiesto impreso. Las cuatro correcciones que Yusef anotó a
  # mano sobre las dos copias del legacy viven en la vista; acá solo se arma la
  # data. El `layout: "print"` es el mismo del Warehouse Receipt, que trae de
  # regalo la cadena de `?print=true` (imprime y, con `cerrar=1`, se cierra).
  def documento
    @cajas = @manifiesto.cajas.includes(:tamano_caja)
    @paquetes = @manifiesto.paquetes.includes(:cliente, :tipo_envio).order(:id)
    render layout: "print"
  end

  # Endpoint JSON para el autocomplete del manifiesto en el form del paquete.
  def buscar
    q = params[:q].to_s.strip
    scope = Manifiesto.activos.includes(:sucursal_origen).order(created_at: :desc).limit(10)
    scope = scope.buscar(q) if q.present?
    render json: scope.map { |m|
      {
        id: m.id,
        numero: ERB::Util.html_escape(m.numero),
        estado: ERB::Util.html_escape(m.estado.to_s),
        fecha_enviado: m.fecha_enviado&.strftime("%d/%m/%Y %H:%M"),
        sucursal: ERB::Util.html_escape(m.sucursal_origen&.codigo.to_s),
        paquetes_count: m.paquetes.count
      }
    }
  end

  # C21-02 · Esta pantalla es **de Miami**. Lo que llena San Pedro se fue a
  # `/guias-y-aduana` (`PR-U1`), así que acá no hay dos mitades que separar:
  # `SOLO_MIAMI` y el segundo `before_action` que hacían falta para eso se
  # fueron con la sección.
  private def authorize_manifiestos
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:manifiestos)
  end

  def set_manifiesto
    @manifiesto = Manifiesto.find(params[:id])
  end

  def respond_to_paquete_change(message)
    @paquetes = @manifiesto.paquetes.includes(:cliente, :sucursal, :sucursal_destino).order(:created_at)
    @manifiesto.reload
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("manifiesto-paquetes", partial: "manifiestos/paquetes_table", locals: { manifiesto: @manifiesto, paquetes: @paquetes }),
          # C21-06 · Los botones de cierre **también**. Se actualizaba solo la
          # tabla, y como «Solo Finalizar» solo se dibuja con `paquetes.any?`,
          # al agregar el primer paquete la tabla se llenaba y el botón no
          # aparecía: la única forma de finalizar era recargar la pantalla. Y al
          # quitar el último pasa al revés — el botón quedaba ofreciendo
          # finalizar un manifiesto vacío.
          turbo_stream.update("manifiesto-acciones", partial: "manifiestos/acciones", locals: { manifiesto: @manifiesto, paquetes: @paquetes }),
          turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { notice: message })
        ]
      end
      format.html { redirect_to @manifiesto, notice: message }
    end
  end

  # C21-02 · Lo que la pantalla puede mandar. Las columnas viejas `tipo_envio`,
  # `numero_guia` y `numero_caja` **salen de acá**: dejan de escribirse y quedan
  # solo para leer lo que ya está grabado.
  # C21-06 · El candado. Un manifiesto cerrado solo lo reabre quien puede
  # (`Manifiesto#editable_por?`), y el que no puede **se entera**: se le contesta
  # con un aviso, no se le acepta el formulario para descartárselo callado, que
  # es lo que pasaba mientras las dos mitades compartían pantalla.
  def manifiesto_params
    params.require(:manifiesto).permit(
      :numero, :expedido_por, :empresa_manifiesto_id,
      # El encabezado que Yusef anotó campo por campo sobre el impreso.
      :consignatario_id, :tipo_envio_proveedor_id, :sucursal_entrega_id, :es_prioridad,
      # `sucursal_origen_id` es lo que despierta la numeración anual. Estaba
      # fuera de esta lista, y por eso `MM2026000001` no corría nunca (RP-46).
      :sucursal_origen_id,
      # `A7-07` · Oficial o interno. El formulario solo lo deja elegir al crear;
      # en uno guardado va como hidden, porque el número ya salió y la carga ya
      # se movió con las reglas de su tipo.
      :tipo,
      tipo_envio_ids: []
    )
  end

  # C21-02 · La sucursal de origen es lo que le da número anual al manifiesto.
  # Si la pantalla no la manda, se usa la misma regla que /etiquetar y
  # /entrega_personal — vive en `Sucursal` justamente para que no se separen.
  def sucursal_origen_para(atributos)
    return atributos[:sucursal_origen_id] if atributos[:sucursal_origen_id].present?

    Sucursal.recepcion_por_defecto_para(Current.user)&.id
  end

  def assigns_del_formulario
    @empresas          = EmpresaManifiesto.activos.order(:nombre)
    @tipo_envios       = TipoEnvio.activos.order(:nombre)
    @tipos_proveedor   = TipoEnvioProveedor.activos.ordered
    @consignatarios    = Consignatario.activos.ordered
    @sucursales_origen = Sucursal.de_recepcion
    @sucursales_entrega = Sucursal.de_retiro
  end
end
