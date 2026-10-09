# C18-06: CRUD admin del catálogo de «enviado según política», gemelo del de
# motivos de retención. Yusef: *"entre más cosas nos dejes crear, menos te
# molestaremos"* — las frases las ajusta él.
class MotivosEnvioPoliticaController < ApplicationController
  before_action :solo_admin
  before_action :set_motivo, only: %i[edit update]

  def index
    @motivos = MotivoEnvioPolitica.ordered
  end

  def new
    @motivo = MotivoEnvioPolitica.new
  end

  def create
    @motivo = MotivoEnvioPolitica.new(motivo_params)
    if @motivo.save
      redirect_to motivos_envio_politica_path, notice: "Motivo creado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @motivo.update(motivo_params)
      redirect_to motivos_envio_politica_path, notice: "Motivo actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private


  def set_motivo
    @motivo = MotivoEnvioPolitica.find(params[:id])
  end

  def motivo_params
    params.require(:motivo_envio_politica).permit(:nombre, :texto_al_cliente, :position, :activo)
  end
  # `RP-58` · Va por `can_access?` y no por `require_admin`: toda regla de rol
  # tiene que pasar por el mismo lugar, o una pantalla de permisos diría que se
  # puede algo que este controller después niega.
  def solo_admin
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:motivos_envio_politica)
  end
end
