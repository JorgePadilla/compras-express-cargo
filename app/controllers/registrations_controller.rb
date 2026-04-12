class RegistrationsController < ApplicationController
  include ClienteAuthentication

  allow_unauthenticated_access
  allow_unauthenticated_cliente_access

  layout "application"

  def new
    @cliente = Cliente.new
  end

  def create
    @cliente = Cliente.new(registration_params)
    @cliente.activo = true

    if @cliente.save
      start_new_cliente_session_for(@cliente)
      redirect_to cuenta_root_path, notice: "Bienvenido a Compras Express Cargo! Tu cuenta ha sido creada exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:cliente).permit(:nombre, :apellido, :email, :telefono, :password, :password_confirmation)
  end
end
