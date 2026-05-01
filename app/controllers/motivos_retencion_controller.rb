# PR-D2.b: CRUD admin del catálogo de motivos por los que un paquete
# puede ser retenido. Yusef pidió poder agregar/editar la lista sin
# que tengamos que tocar seeds.
class MotivosRetencionController < ApplicationController
  before_action :require_admin
  before_action :set_motivo, only: %i[edit update]

  def index
    @motivos = MotivoRetencion.ordered
  end

  def new
    @motivo = MotivoRetencion.new
  end

  def create
    @motivo = MotivoRetencion.new(motivo_params)
    if @motivo.save
      redirect_to motivos_retencion_path, notice: "Motivo creado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @motivo.update(motivo_params)
      redirect_to motivos_retencion_path, notice: "Motivo actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def require_admin
    redirect_to(root_path, alert: "Solo admin.") unless admin?
  end

  def set_motivo
    @motivo = MotivoRetencion.find(params[:id])
  end

  def motivo_params
    params.require(:motivo_retencion).permit(:nombre, :descripcion, :position, :activo)
  end
end
