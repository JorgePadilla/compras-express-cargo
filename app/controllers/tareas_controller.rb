class TareasController < ApplicationController
  include ResuelveLaFranja

  # PR-9.a: este controller venía SIN ningún filtro de autorización desde
  # PR #66 — cualquier usuario autenticado podía crear, editar o borrar
  # tareas de cualquier paquete. Se cierra ahora que la franja de contexto
  # expone `completar` a los operarios.
  #
  # Editar/borrar: quien define el trabajo (supervisores + SAC).
  # Completar/iniciar: además los operarios que lo ejecutan.
  # Crear: los mismos que ejecutan (C17-01, Jorge 2026-08-26). Hasta acá crear
  # era de GESTION_ROLES y el que estaba en la pistola —el digitador— podía
  # marcar una tarea hecha pero no dejar una. Yusef solo dijo *"el cliente no
  # puede poner una tarea, solo nosotros"* (C16-01) y nunca quién de nosotros:
  # queda como respuesta provisoria en `RP-45`. Si dice que no, esta constante
  # vuelve a `GESTION_ROLES` y con ella `can_crear_tareas?` y un test.
  GESTION_ROLES  = %w[supervisor_miami supervisor_caja supervisor_prefactura sac].freeze
  EJECUCION_ROLES = (GESTION_ROLES + %w[digitador_miami cajero entrega_despacho]).freeze
  CREACION_ROLES  = EJECUCION_ROLES

  before_action :authorize_creacion,  only: [ :new, :create ]
  before_action :authorize_gestion,   only: [ :edit, :update, :destroy ]
  before_action :authorize_ejecucion, only: [ :index, :iniciar, :completar, :reabrir ]
  before_action :set_paquete
  before_action :set_tarea, only: [ :edit, :update, :destroy, :iniciar, :completar, :reabrir ]

  # Anidada bajo paquete: las de ese paquete, como siempre.
  # Top-level: la bandeja — lo que el área de uno tiene abierto, sin tener que
  # saber de antemano en qué paquete está la tarea.
  def index
    return tareas_del_paquete if @paquete

    @solo_mias = params[:mias] == "1"
    @incluir_realizadas = params[:realizadas] == "1"

    # `visibles_para` es la misma segmentación por área que usan las notas
    # permanentes: un digitador no tiene por qué ver la cola de Caja.
    tareas = Tarea.visibles_para(Current.user)
    tareas = tareas.abiertas unless @incluir_realizadas
    tareas = tareas.where(asignado_a: Current.user) if @solo_mias

    # Las empezadas primero: son las que alguien dejó a medias.
    @tareas = tareas.includes(:asignado_a, :completado_por, :cliente, paquete: :cliente)
                    .order(Arel.sql("CASE estado WHEN 'en_proceso' THEN 0 WHEN 'pendiente' THEN 1 ELSE 2 END"),
                           created_at: :asc)
                    .page(params[:page]).per(per_page_sanitized)

    render :bandeja
  end

  def new
    @tarea = nueva_tarea
    @tarea.cliente_id ||= params[:cliente_id]
    # El área del que la crea, no «todas»: si un digitador la deja en blanco
    # la ve cualquiera, pero lo normal es que sea para los suyos.
    @tarea.departamento ||= departamento_por_defecto
    @users = User.where(activo: true).order(:nombre)
  end

  def create
    @tarea = nueva_tarea(tarea_params)

    # C17-01: desde la bandeja la tarea puede colgar de un paquete escribiendo
    # su tracking. Se resuelve acá y no por `paquete_id` en los params: el
    # operario tiene el tracking en la mano, no un id, y aceptar el id por
    # parámetro es la puerta para colgarla de cualquier paquete.
    tracking = params.dig(:tarea, :tracking).to_s.strip
    if @paquete.nil? && tracking.present? && !desde_franja?
      @tarea.paquete = paquete_del_tracking(tracking, @tarea.cliente_id)
      if @tarea.paquete.nil?
        @tarea.valid? # `errors.add` antes de `valid?` se pierde
        @tarea.errors.add(:base, "No hay ningún paquete con el tracking #{tracking}")
        return render_fallo(:new)
      end
    end
    # C17-02: desde la franja el paquete casi nunca existe todavía —se está
    # recibiendo—, así que el tracking se guarda en la tarea y
    # `Tarea.atar_al_paquete!` la re-apunta cuando el paquete se guarda.
    @tarea.tracking = tracking if desde_franja? && @paquete.nil?

    if @tarea.save
      return responder_a_la_franja if desde_franja?

      redirect_to destino_post_guardado, notice: "Tarea creada."
    else
      return responder_a_la_franja_con_errores if desde_franja?

      render_fallo(:new)
    end
  end

  def edit
    @users = User.where(activo: true).order(:nombre)
  end

  def update
    if @tarea.update(tarea_params)
      redirect_to destino_post_guardado, notice: "Tarea actualizada."
    else
      render_fallo(:edit)
    end
  end

  def destroy
    @tarea.destroy
    redirect_to destino_post_guardado, notice: "Tarea eliminada."
  end

  def iniciar
    @tarea.iniciar!(Current.user)
    redirect_back_to_tareas("Tarea iniciada.")
  end

  # El checkbox de la franja de contexto pega aquí. La respuesta turbo_stream
  # saca la fila, corrige el contador y deja constancia de quién la marcó —
  # el registro duro queda en `completado_por` / `completada_en`.
  def completar
    @tarea.completar!(Current.user)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(helpers.dom_id(@tarea)),
          turbo_stream.update("tareas-pendientes-count", tareas_pendientes_count),
          turbo_stream.prepend("flash-messages", partial: "shared/flash",
                               locals: { notice: "Tarea completada por #{Current.user.iniciales_display}." })
        ]
      end
      format.html { redirect_back_to_tareas("Tarea completada.") }
    end
  end

  def reabrir
    @tarea.reabrir!
    redirect_back_to_tareas("Tarea reabierta.")
  end

  private

  def tareas_del_paquete
    @tareas = @paquete.tareas.includes(:asignado_a, :completado_por).order(created_at: :desc)
  end

  # Anidada bajo paquete → cuelga del paquete. Top-level → tarea de cliente
  # (la que cualquier área le deja al cliente y el digitador ve al escanear).
  def nueva_tarea(attrs = {})
    @paquete ? @paquete.tareas.new(attrs) : Tarea.new(attrs)
  end

  # A donde la tarea está pegada: al paquete si lo tiene —también cuando llegó
  # por la ruta top-level con un tracking—, si no a la ficha del cliente.
  def destino_post_guardado
    destino = @paquete || @tarea.paquete
    destino ? paquete_tareas_path(destino) : cliente_path(@tarea.cliente_id)
  end

  def render_fallo(vista)
    @users = User.where(activo: true).order(:nombre)
    render vista, status: :unprocessable_entity
  end

  # El mini-form de la franja manda `desde_franja=1`. Hace falta un
  # discriminador propio: Turbo manda `Accept: text/vnd.turbo-stream.html` en
  # **todo** POST de formulario, así que un `respond_to` a secas atraparía
  # también el `/tareas/new` de página completa.
  def desde_franja?
    params[:desde_franja] == "1"
  end

  # Se reemplaza el bloque entero de tareas —no se agrega una fila—: el `<ul>`
  # solo existe cuando hay tareas, y el badge cambia de color con ellas. Un
  # `prepend` fallaría justo en el caso más común, la primera tarea. El
  # tracking para re-pintar es el **fresco** que acaba de mandar el JS, no el
  # que tenía la franja al cargar (ver `ResuelveLaFranja`).
  def responder_a_la_franja
    cliente = @tarea.cliente
    tracking = params.dig(:tarea, :tracking).to_s.strip.upcase.presence || @paquete&.tracking
    paquete = @paquete || paquete_de_la_franja(cliente, tracking)

    render turbo_stream: [
      turbo_stream.replace("tareas-de-la-franja", partial: "panel_contexto/tareas",
                           locals: { cliente: cliente, tareas: tareas_de_la_franja(cliente),
                                     paquete: paquete, tracking: tracking }),
      turbo_stream.prepend("flash-messages", partial: "shared/flash",
                           locals: { notice: "Tarea dejada para #{@tarea.departamento_label}." })
    ]
  end

  # Solo el form, con sus errores, para que el diálogo siga abierto. Turbo
  # procesa las respuestas turbo_stream con cualquier status.
  def responder_a_la_franja_con_errores
    render turbo_stream: turbo_stream.replace(
      "tarea-desde-franja-form", partial: "panel_contexto/tarea_desde_franja_form",
      locals: { tarea: @tarea, paquete: @paquete }
    ), status: :unprocessable_entity
  end

  # El paquete de ese tracking, **del cliente elegido**: los couriers reciclan
  # trackings y el mismo código puede estar en dos clientes. Sin cliente, sin
  # scope, y `derivar_cliente_desde_paquete` lo completa desde el paquete. En
  # un split va a la Caja 1 (`NULLS LAST`: una caja sin número no se cuela
  # primera). El bloqueo de avance es por caja —la pre-factura avanza caja por
  # caja con `update!`— y el manifiesto no lo mira (`update_all`).
  def paquete_del_tracking(tracking, cliente_id)
    scope = cliente_id.present? ? Paquete.where(cliente_id: cliente_id) : Paquete.all
    scope.buscar_escaneado(tracking)
         .order(Arel.sql("numero_caja ASC NULLS LAST, id ASC"))
         .first
  end

  def departamento_por_defecto
    helpers.departamento_por_defecto_de(Current.user)
  end

  # Cuántas tareas abiertas le quedan a este cliente para el área del
  # usuario — alimenta el contador de la franja.
  def tareas_pendientes_count
    Tarea.abiertas
         .para_cliente(@tarea.cliente_id)
         .visibles_para(Current.user)
         .count
         .to_s
  end

  def redirect_back_to_tareas(mensaje)
    destino = @paquete || @tarea.paquete
    if destino
      redirect_to paquete_tareas_path(destino), notice: mensaje
    else
      redirect_back fallback_location: root_path, notice: mensaje
    end
  end

  def authorize_creacion
    require_role(*CREACION_ROLES)
  end

  def authorize_gestion
    require_role(*GESTION_ROLES)
  end

  def authorize_ejecucion
    require_role(*EJECUCION_ROLES)
  end

  # PR-9.a: `completar` / `reabrir` también se sirven desde rutas top-level
  # (`/tareas/:id/completar`), porque una tarea de cliente puede no tener
  # paquete todavía. Cuando viene anidada seguimos scopeando por paquete.
  def set_paquete
    @paquete = Paquete.find(params[:paquete_id]) if params[:paquete_id].present?
  end

  def set_tarea
    @tarea = @paquete ? @paquete.tareas.find(params[:id]) : Tarea.find(params[:id])
  end

  def tarea_params
    params.require(:tarea).permit(
      :titulo, :descripcion, :asignado_a_id, :notas,
      :cliente_id, :departamento, :bloquea_avance, :tracking
    )
  end
end
