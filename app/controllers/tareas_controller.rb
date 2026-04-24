class TareasController < ApplicationController
  before_action :set_paquete
  before_action :set_tarea, only: [ :edit, :update, :destroy, :iniciar, :completar, :reabrir ]

  def index
    @tareas = @paquete.tareas.includes(:asignado_a, :completado_por).order(created_at: :desc)
  end

  def new
    @tarea = @paquete.tareas.new
    @users = User.where(activo: true).order(:name)
  end

  def create
    @tarea = @paquete.tareas.new(tarea_params)
    if @tarea.save
      redirect_to paquete_tareas_path(@paquete), notice: "Tarea creada."
    else
      @users = User.where(activo: true).order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @users = User.where(activo: true).order(:name)
  end

  def update
    if @tarea.update(tarea_params)
      redirect_to paquete_tareas_path(@paquete), notice: "Tarea actualizada."
    else
      @users = User.where(activo: true).order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tarea.destroy
    redirect_to paquete_tareas_path(@paquete), notice: "Tarea eliminada."
  end

  def iniciar
    @tarea.iniciar!(Current.user)
    redirect_to paquete_tareas_path(@paquete), notice: "Tarea iniciada."
  end

  def completar
    @tarea.completar!(Current.user)
    redirect_to paquete_tareas_path(@paquete), notice: "Tarea completada."
  end

  def reabrir
    @tarea.reabrir!
    redirect_to paquete_tareas_path(@paquete), notice: "Tarea reabierta."
  end

  private

  def set_paquete
    @paquete = Paquete.find(params[:paquete_id])
  end

  def set_tarea
    @tarea = @paquete.tareas.find(params[:id])
  end

  def tarea_params
    params.require(:tarea).permit(:titulo, :descripcion, :asignado_a_id, :notas)
  end
end
