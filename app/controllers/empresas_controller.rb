class EmpresasController < ApplicationController
  before_action :solo_admin
  before_action :set_empresa

  def show
  end

  def edit
  end

  def update
    if @empresa.update(empresa_params)
      redirect_to empresa_path, notice: "Datos de empresa actualizados."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private


  def set_empresa
    @empresa = Empresa.instance
  end

  def empresa_params
    params.require(:empresa).permit(
      :nombre, :rtn, :telefono, :email_contacto, :direccion,
      :ciudad, :pais, :moneda_default, :isv_rate, :sitio_web,
      :terminos_factura, :logo
    )
  end
  # `RP-58` · Va por `can_access?` y no por `require_admin`: toda regla de rol
  # tiene que pasar por el mismo lugar, o una pantalla de permisos diría que se
  # puede algo que este controller después niega.
  def solo_admin
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:empresa_settings)
  end
end
