# C19-04: CRUD admin del catálogo de descripciones frecuentes del contenido.
# Calcado de PlantillasNotasClienteController; el picker (Stimulus) las
# inyecta en `paquete.descripcion` en las tres pantallas gemelas.
class PlantillasDescripcionController < ApplicationController
  before_action :require_admin
  before_action :set_plantilla, only: %i[edit update]

  def index
    @plantillas = PlantillaDescripcion.ordered
  end

  def new
    @plantilla = PlantillaDescripcion.new
  end

  def create
    @plantilla = PlantillaDescripcion.new(plantilla_params)
    if @plantilla.save
      redirect_to plantillas_descripcion_path, notice: "Plantilla creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @plantilla.update(plantilla_params)
      redirect_to plantillas_descripcion_path, notice: "Plantilla actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def require_admin
    redirect_to(root_path, alert: "Solo admin.") unless admin?
  end

  def set_plantilla
    @plantilla = PlantillaDescripcion.find(params[:id])
  end

  def plantilla_params
    params.require(:plantilla_descripcion).permit(:titulo, :texto, :position, :activo)
  end
end
