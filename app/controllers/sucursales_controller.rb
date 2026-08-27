class SucursalesController < ApplicationController
  # require_authentication viene de ApplicationController (Authentication concern);
  # aqui apilamos chequeo explicito de rol admin antes de cualquier accion.
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
    params.require(:sucursal).permit(:codigo, :codigo_ep, :nombre, :pais, :ubicacion, :activo,
                                      :retiro_por_defecto, :recibe_carga, :recepcion_por_defecto)
  end

  def require_admin_access
    # Si no hay sesion activa, require_authentication (concern) ya lo habra
    # redirigido antes. Defensive: segundo chequeo por si alguien cambia el
    # orden de callbacks.
    unless Current.user
      redirect_to new_session_path, alert: "Iniciá sesión para continuar."
      return
    end

    return if Current.user.admin?

    # 403-equivalente: redirige con alert y aborta la accion.
    redirect_to root_path, alert: "Solo administradores pueden gestionar sucursales."
  end
end
