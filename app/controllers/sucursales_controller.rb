class SucursalesController < ApplicationController
  before_action :require_admin_access
  before_action :set_sucursal, only: [ :edit, :update, :destroy ]

  def index
    @sucursales = Sucursal.ordered
  end

  def new
    @sucursal = Sucursal.new(activo: true)
  end

  def create
    @sucursal = Sucursal.new(sucursal_params)
    if @sucursal.save
      redirect_to sucursales_path, notice: "Sucursal creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @sucursal.update(sucursal_params)
      redirect_to sucursales_path, notice: "Sucursal actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @sucursal.paquetes.exists?
      redirect_to sucursales_path, alert: "No se puede eliminar: la sucursal tiene paquetes vinculados."
    else
      @sucursal.destroy
      redirect_to sucursales_path, notice: "Sucursal eliminada."
    end
  end

  private

  def set_sucursal
    @sucursal = Sucursal.find(params[:id])
  end

  def sucursal_params
    params.require(:sucursal).permit(:codigo, :nombre, :pais, :ubicacion, :codigo_recepcion_prefix, :activo)
  end

  def require_admin_access
    return if Current.user&.admin?
    redirect_to root_path, alert: "Solo administradores pueden gestionar sucursales."
  end
end
