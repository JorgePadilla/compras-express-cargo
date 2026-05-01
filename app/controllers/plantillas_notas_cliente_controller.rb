# PR-D2.b: CRUD admin del catálogo de plantillas reutilizables para
# `notas_al_cliente`. El picker (Stimulus) de notas al cliente las
# inyecta directo en el textarea del paquete.
class PlantillasNotasClienteController < ApplicationController
  before_action :require_admin
  before_action :set_plantilla, only: %i[edit update]

  def index
    @plantillas = PlantillaNotaCliente.ordered
  end

  def new
    @plantilla = PlantillaNotaCliente.new
  end

  def create
    @plantilla = PlantillaNotaCliente.new(plantilla_params)
    if @plantilla.save
      redirect_to plantillas_notas_cliente_path, notice: "Plantilla creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @plantilla.update(plantilla_params)
      redirect_to plantillas_notas_cliente_path, notice: "Plantilla actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def require_admin
    redirect_to(root_path, alert: "Solo admin.") unless admin?
  end

  def set_plantilla
    @plantilla = PlantillaNotaCliente.find(params[:id])
  end

  def plantilla_params
    params.require(:plantilla_nota_cliente).permit(:titulo, :texto, :position, :activo)
  end
end
