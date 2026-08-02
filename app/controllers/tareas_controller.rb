class TareasController < ApplicationController
  # PR-9.a: este controller venía SIN ningún filtro de autorización desde
  # PR #66 — cualquier usuario autenticado podía crear, editar o borrar
  # tareas de cualquier paquete. Se cierra ahora que la franja de contexto
  # expone `completar` a los operarios.
  #
  # Crear/editar/borrar: quien define el trabajo (supervisores + SAC).
  # Completar/iniciar: además los operarios que lo ejecutan.
  GESTION_ROLES  = %w[supervisor_miami supervisor_caja supervisor_prefactura sac].freeze
  EJECUCION_ROLES = (GESTION_ROLES + %w[digitador_miami cajero entrega_despacho]).freeze

  before_action :authorize_gestion,   only: [ :new, :create, :edit, :update, :destroy ]
  before_action :authorize_ejecucion, only: [ :index, :iniciar, :completar, :reabrir ]
  before_action :set_paquete
  before_action :set_tarea, only: [ :edit, :update, :destroy, :iniciar, :completar, :reabrir ]

  def index
    @tareas = @paquete.tareas.includes(:asignado_a, :completado_por).order(created_at: :desc)
  end

  def new
    @tarea = nueva_tarea
    @tarea.cliente_id ||= params[:cliente_id]
    @users = User.where(activo: true).order(:nombre)
  end

  def create
    @tarea = nueva_tarea(tarea_params)
    if @tarea.save
      redirect_to destino_post_guardado, notice: "Tarea creada."
    else
      @users = User.where(activo: true).order(:nombre)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @users = User.where(activo: true).order(:nombre)
  end

  def update
    if @tarea.update(tarea_params)
      redirect_to destino_post_guardado, notice: "Tarea actualizada."
    else
      @users = User.where(activo: true).order(:nombre)
      render :edit, status: :unprocessable_entity
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

  # Anidada bajo paquete → cuelga del paquete. Top-level → tarea de cliente
  # (la que cualquier área le deja al cliente y el digitador ve al escanear).
  def nueva_tarea(attrs = {})
    @paquete ? @paquete.tareas.new(attrs) : Tarea.new(attrs)
  end

  def destino_post_guardado
    @paquete ? paquete_tareas_path(@paquete) : cliente_path(@tarea.cliente_id)
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
      :cliente_id, :departamento, :bloquea_avance
    )
  end
end
