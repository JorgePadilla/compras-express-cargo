# PR-D2.b: CRUD admin del catálogo de plantillas reutilizables para
# `notas_al_cliente`. El picker (Stimulus) de notas al cliente las
# inyecta directo en el textarea del paquete.
class PlantillasNotasClienteController < ApplicationController
  before_action :solo_admin
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


  def set_plantilla
    @plantilla = PlantillaNotaCliente.find(params[:id])
  end

  def plantilla_params
    params.require(:plantilla_nota_cliente).permit(:titulo, :texto, :position, :activo)
  end
  # `RP-58` · Va por `can_access?` y no por `require_admin`: toda regla de rol
  # tiene que pasar por el mismo lugar, o una pantalla de permisos diría que se
  # puede algo que este controller después niega.
  def solo_admin
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:plantillas_notas_cliente)
  end
end
