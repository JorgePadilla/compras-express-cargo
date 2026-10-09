# PR-D6.a: CRUD admin del catálogo de servicios extra.
class ServiciosExtraController < ApplicationController
  before_action :solo_admin
  before_action :set_servicio, only: %i[edit update]

  def index
    @servicios = ServicioExtra.ordered
  end

  def new
    @servicio = ServicioExtra.new(activo: true, moneda: "USD", precio_incluye_isv: true)
  end

  def create
    @servicio = ServicioExtra.new(servicio_params)
    if @servicio.save
      redirect_to servicios_extra_path, notice: "Servicio creado (#{@servicio.codigo})."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @servicio.update(servicio_params)
      redirect_to servicios_extra_path, notice: "Servicio actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private


  def set_servicio
    @servicio = ServicioExtra.find(params[:id])
  end

  def servicio_params
    params.require(:servicio_extra).permit(
      :codigo, :descripcion, :costo, :precio_venta, :moneda,
      :precio_incluye_isv, :position, :activo, :notas,
      :minimo_monto, :minimo_moneda
    )
  end
  # `RP-58` · Va por `can_access?` y no por `require_admin`: toda regla de rol
  # tiene que pasar por el mismo lugar, o una pantalla de permisos diría que se
  # puede algo que este controller después niega.
  def solo_admin
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:servicios_extra)
  end
end
