class SessionsController < ApplicationController
  include ClienteAuthentication
  allow_unauthenticated_access only: %i[ new create ]
  allow_unauthenticated_cliente_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Demasiados intentos. Intenta de nuevo mas tarde." }

  def new
  end

  def create
    email = params[:email_address]
    password = params[:password]

    if user = User.authenticate_by(email_address: email, password: password)
      start_new_session_for user
      redirect_to after_authentication_url
    elsif cliente = Cliente.activos.authenticate_by(email: email, password: password)
      start_new_cliente_session_for(cliente)
      redirect_to cuenta_root_url
    else
      redirect_to new_session_path, alert: "Correo o contrasena incorrectos."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end
end
