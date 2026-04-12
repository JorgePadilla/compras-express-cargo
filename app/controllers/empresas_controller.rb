class EmpresasController < ApplicationController
  before_action :require_admin
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

  def require_admin
    redirect_to(root_path, alert: "Solo admin puede editar la empresa.") unless Current.user&.admin?
  end

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
end
