class ReempaquesController < ApplicationController
  before_action :set_paquete
  before_action :set_reempaque, only: [ :show ]

  def index
    @reempaques = @paquete.reempaques.includes(:hecho_por).order(realizado_en: :desc)
  end

  def show
  end

  def new
    @reempaque = @paquete.reempaques.new
    @tareas_abiertas = @paquete.tareas.abiertas.order(created_at: :asc)
  end

  def create
    @reempaque = @paquete.reempaques.new(reempaque_params)
    @reempaque.hecho_por = Current.user

    if @reempaque.save
      redirect_to paquete_reempaques_path(@paquete),
                  notice: "Re-empaque registrado. Ahorro volumétrico: #{@reempaque.ahorro_volumetrico} lbs."
    else
      @tareas_abiertas = @paquete.tareas.abiertas.order(created_at: :asc)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_paquete
    @paquete = Paquete.find(params[:paquete_id])
  end

  def set_reempaque
    @reempaque = @paquete.reempaques.find(params[:id])
  end

  def reempaque_params
    params.require(:reempaque).permit(
      :alto_despues, :largo_despues, :ancho_despues, :peso_despues,
      :notas, :tarea_id
    )
  end
end
