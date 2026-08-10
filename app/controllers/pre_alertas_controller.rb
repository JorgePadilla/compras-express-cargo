class PreAlertasController < ApplicationController
  before_action :set_pre_alerta, only: %i[show edit update anular destinos_disponibles mover_paquete]

  def index
    @pre_alertas = base_scope.includes(:cliente, :tipo_envio, :pre_alerta_paquetes).recientes
    @pre_alertas = apply_filters(@pre_alertas)
    @pre_alertas = @pre_alertas.page(params[:page]).per(per_page_sanitized)
    @tipo_envios = TipoEnvio.activos.order(:nombre)
  end

  def show
  end

  # PR-D4.a.2: endpoint JSON para el modal "Mover a Pre-Alerta Existente".
  # Devuelve PAs activas que matchean el query (numero_documento, titulo
  # o nombre del cliente). Limit 12 resultados.
  def buscar
    term = params[:q].to_s.strip
    @resultados = PreAlerta.includes(:cliente).activas
                            .buscar(term)
                            .order(created_at: :desc)
                            .limit(12)
    render json: @resultados.map { |pa|
      {
        id: pa.id,
        numero: pa.numero_documento,
        titulo: pa.titulo.presence || "(sin título)",
        cliente: "#{pa.cliente.codigo} — #{pa.cliente.nombre_completo}",
        consolidado: pa.consolidado,
        estado: pa.estado
      }
    }
  end

  def new
    @pre_alerta = PreAlerta.new
    @pre_alerta.pre_alerta_paquetes.build
    @tipo_envios = TipoEnvio.activos.order(:nombre)
    cargar_sugerencias
    # PR-C6.26: el dropdown arrancaba vacío aunque el modelo backfillea CER en
    # `before_validation on: :create` — el default existía pero no se veía, y
    # el operario tenía que elegirlo igual. Yusef: "preseleccionar de los
    # dropdown". Se muestra el mismo que se iba a aplicar.
    @tipo_envio_sugerido = @tipo_envios.find { |t| t.codigo == "cer" }
  end

  def create
    @pre_alerta = PreAlerta.new(pre_alerta_params)
    @pre_alerta.creado_por_tipo = "usuario"
    @pre_alerta.creado_por_id = Current.user.id

    if @pre_alerta.save
      redirect_to pre_alerta_path(@pre_alerta), notice: "Pre-Alerta #{@pre_alerta.numero_documento} creada exitosamente."
    else
      @tipo_envios = TipoEnvio.activos.order(:nombre)
      cargar_sugerencias
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @tipo_envios = TipoEnvio.activos.order(:nombre)
    cargar_sugerencias
  end

  # ── Autosave (JSON) ──
  #
  # PR-C6.43: esta rama faltaba, y el que faltara **duplicaba paquetes**.
  #
  # El editor guarda por fetch mandando `autosave=true`, y espera que la
  # respuesta le devuelva el `id` que la base le asignó a cada fila nueva
  # (`_injectNewPaqueteIds`). Con la respuesta vieja —`{ ok: true }`, sin
  # `new_paquetes`— el bucle del JS no corría nunca: la fila recién creada se
  # quedaba sin su `id` oculto, y al segundo F8 se reenviaba como si fuera
  # nueva. `accepts_nested_attributes_for` creaba un SEGUNDO registro, que por
  # `crear_paquete_esperado` metía un segundo Paquete en bodega.
  #
  # F8 es la única forma de guardar en esta pantalla, así que el segundo apretón
  # era la ruta normal, no un caso raro. El portal del cliente nunca lo tuvo
  # porque su `update` sí devuelve `new_paquetes` desde el principio.
  #
  # La rama `format.json` vieja (`ok`/`errores`) se conserva: el JS siempre manda
  # `autosave=true`, así que cae acá, y lo otro sigue sirviendo para un PATCH
  # JSON hecho a mano.
  def update
    return autosave if params[:autosave] == "true"

    if @pre_alerta.update(pre_alerta_params)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("pre_alerta_header", partial: "pre_alertas/header", locals: { pre_alerta: @pre_alerta }),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Pre-Alerta actualizada." })
          ]
        end
        format.html { redirect_to pre_alerta_path(@pre_alerta), notice: "Pre-Alerta actualizada." }
        # PR-C6.25: el editor guarda por fetch (el botón "Guardar (F8)" es
        # `type=button`, no un submit), así que necesita una respuesta JSON.
        # Sin esta rama el guardado devolvía HTML y el Stimulus no sabía qué
        # hacer con él.
        format.json { render json: { ok: true } }
      end
    else
      @tipo_envios = TipoEnvio.activos.order(:nombre)
      cargar_sugerencias
      respond_to do |format|
        format.json { render json: { ok: false, errores: @pre_alerta.errors.full_messages }, status: :unprocessable_entity }
        format.any  { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # PR-C6.48: los destinos posibles para mover un paquete.
  #
  # La lista de admin es deliberadamente más ancha que la del portal: **de
  # cualquier cliente**, y sin exigir que el tipo de envío coincida. Yusef:
  # *"se permite mover a pre-alerta de cualquier cliente (caso típico: corregir
  # asignación equivocada)"* — si el paquete cayó en la pre-alerta del cliente
  # equivocado, el destino correcto es justamente de otro cliente.
  #
  # Lo único que se sigue bloqueando es meterlo en una consolidación ya cerrada:
  # ahí el cliente ya no puede reaccionar.
  def destinos_disponibles
    # El `find` es la validación: si la fila no es de esta pre-alerta, levanta
    # RecordNotFound y no se filtra la lista de nadie.
    @pre_alerta.pre_alerta_paquetes.find(params[:pre_alerta_paquete_id])

    destinos = PreAlerta.activas
                        .includes(:cliente, :tipo_envio)
                        .where.not(id: @pre_alerta.id)
                        .where(finalizado: false)
                        .order(created_at: :desc)
                        .limit(20)

    render json: destinos.map { |pa| destino_json(pa) }
  end

  def mover_paquete
    pap = @pre_alerta.pre_alerta_paquetes.find(params[:pre_alerta_paquete_id])
    destino = PreAlerta.activas.find_by(id: params[:destino_id])

    if destino.nil? || destino.id == @pre_alerta.id
      redirect_to edit_pre_alerta_path(@pre_alerta), alert: "Destino no válido."
      return
    end

    if destino.finalizado?
      redirect_to edit_pre_alerta_path(@pre_alerta),
                  alert: "#{destino.numero_documento} ya se finalizó: no se le pueden agregar paquetes."
      return
    end

    origen_quedo_vacia = mover!(pap, destino)

    if origen_quedo_vacia
      redirect_to pre_alertas_path,
                  notice: "Paquete movido a #{destino.numero_documento}. La pre-alerta origen quedó vacía y fue eliminada."
    else
      redirect_to edit_pre_alerta_path(@pre_alerta),
                  notice: "Paquete movido a #{destino.numero_documento} (#{destino.cliente.codigo})."
    end
  end

  def anular
    @pre_alerta.anular!
    redirect_to pre_alertas_path, notice: "Pre-Alerta #{@pre_alerta.numero_documento} anulada."
  end

  def clean_empty
    count = PreAlerta.activas.vacias.where(created_at: ...30.days.ago).count
    PreAlerta.activas.vacias.where(created_at: ...30.days.ago).find_each(&:soft_delete!)
    redirect_to pre_alertas_path, notice: "#{count} pre-alertas vacias eliminadas."
  end

  private

  # El guardado del editor. Espejo de `Cuenta::PreAlertasController#update`.
  #
  # `errors` y no `errores`: es la llave que el JS lee
  # (`Array.isArray(data.errors)`). Con la otra, el operario veía "Error al
  # guardar" genérico en vez de "el tracking ya existe en esta pre-alerta" —
  # justo el mensaje que hace falta para arreglarlo.
  def autosave
    unless @pre_alerta.update(pre_alerta_params)
      render json: { status: "error", errors: @pre_alerta.errors.full_messages },
             status: :unprocessable_entity
      return
    end

    render json: { status: "saved", new_paquetes: ids_de_las_filas_nuevas }
  end

  # `{ indice_del_form => id_en_la_base }` para las filas que acaban de nacer.
  # Se busca por tracking porque es lo único que el form y la base comparten
  # antes de que exista el id — el mismo criterio que usa el portal.
  def ids_de_las_filas_nuevas
    attrs_por_indice = params.dig(:pre_alerta, :pre_alerta_paquetes_attributes)
    return {} if attrs_por_indice.blank?

    # `each` y no `each_with_object`: `ActionController::Parameters` dejó de ser
    # Enumerable en Rails 5.
    nuevas = {}
    attrs_por_indice.each do |indice, attrs|
      next if attrs[:id].present? || attrs[:_destroy] == "1"

      pap = @pre_alerta.pre_alerta_paquetes.find_by(tracking: attrs[:tracking]&.strip&.upcase)
      nuevas[indice] = pap.id if pap
    end
    nuevas
  end

  # El movimiento en sí. Devuelve si la pre-alerta origen quedó vacía.
  #
  # Deja rastro en el `historial` de las DOS, igual que el portal: un paquete
  # que aparece en otra pre-alerta sin explicación es indistinguible de un
  # error de carga.
  #
  # **No manda mail.** Los movimientos del portal los hace el cliente sobre sus
  # propias pre-alertas; este lo hace el equipo, y avisarle al cliente de una
  # corrección interna es una decisión de negocio que nadie pidió.
  def mover!(pap, destino)
    vacia = false

    PreAlertaPaquete.transaction do
      sello = Time.current.strftime("%d/%m/%Y %H:%M")
      quien = Current.user&.nombre || "el equipo"
      desc = pap.descripcion.presence || pap.tracking.presence || "sin descripcion"

      pap.update!(pre_alerta: destino)

      @pre_alerta.append_historial!(
        "[#{sello}] #{quien} movió el paquete '#{desc}' (#{pap.tracking}) a #{destino.numero_documento} — #{destino.cliente.codigo}."
      )
      destino.append_historial!(
        "[#{sello}] #{quien} trajo el paquete '#{desc}' (#{pap.tracking}) desde #{@pre_alerta.numero_documento} — #{@pre_alerta.cliente.codigo}."
      )

      if @pre_alerta.pre_alerta_paquetes.reload.empty?
        @pre_alerta.soft_delete!
        vacia = true
      end
    end

    vacia
  end

  def destino_json(pa)
    te = pa.tipo_envio
    modalidad = te&.modalidad&.capitalize || "—"

    {
      id: pa.id,
      numero_documento: pa.numero_documento,
      # El código del cliente va en el título porque acá el destino puede ser
      # de OTRO cliente — es el dato que decide si es el correcto.
      titulo: "#{pa.cliente.codigo} · #{pa.titulo}",
      tipo_envio: te&.nombre || "—",
      tipo_envio_descripcion: te&.con_reempaque ? "#{modalidad} con Reempaque" : "#{modalidad} sin Reempaque",
      consolidado: pa.consolidado,
      paquetes_count: pa.pre_alerta_paquetes.size,
      created_at: pa.created_at.strftime("%d/%m/%Y")
    }
  end

  def set_pre_alerta
    @pre_alerta = PreAlerta.find(params[:id])
  end

# PR-C6.36: el catalogo que alimenta el `datalist` del proveedor. Vive en un
# metodo y no repetido en cada accion porque los re-render de error tambien
# lo necesitan — y ahi fue justo donde se olvido la primera vez.
def cargar_sugerencias
  @proveedores_sugeridos = Proveedor.activos.ordered
end

  def base_scope
    if params[:incluir_anulados] == "1" || params[:solo_anulados] == "1"
      PreAlerta.where(deleted_at: nil)
    else
      PreAlerta.activas
    end
  end

  def apply_filters(scope)
    scope = scope.buscar(params[:q]) if params[:q].present?
    scope = scope.by_estado(params[:estado]) if params[:estado].present?
    scope = scope.by_tipo_envio(params[:tipo_envio_id]) if params[:tipo_envio_id].present?
    scope = scope.by_cliente(params[:cliente_id]) if params[:cliente_id].present?
    scope = scope.where(consolidado: true) if params[:solo_consolidados] == "1"
    scope = scope.solo_anulados if params[:solo_anulados] == "1"
    scope = scope.vacias if params[:solo_vacias] == "1"
    scope
  end

  def pre_alerta_params
    params.require(:pre_alerta).permit(
      :cliente_id, :tipo_envio_id, :consolidado, :con_reempaque,
      :notas_grupo, :estado, :titulo, :proveedor,
      pre_alerta_paquetes_attributes: %i[id tracking descripcion fecha instrucciones _destroy]
    )
  end
end
