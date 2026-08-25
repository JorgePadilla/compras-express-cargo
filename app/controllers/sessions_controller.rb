class SessionsController < ApplicationController
  include ClienteAuthentication
  allow_unauthenticated_access only: %i[ new create destroy ]
  allow_unauthenticated_cliente_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Demasiados intentos. Intenta de nuevo mas tarde." }

  def new
  end

  def create
    # El campo se sigue llamando `email_address` porque para un empleado eso es:
    # su correo. Para un cliente puede venir tambien el codigo de casillero, y de
    # eso se encarga `Cliente.autenticar`.
    identificador = params[:email_address]
    password = params[:password]

    if user = User.authenticate_by(email_address: identificador, password: password)
      start_new_session_for user
      redirect_to after_authentication_url
    elsif cliente = Cliente.autenticar(identificador, password)
      start_new_cliente_session_for(cliente)
      redirect_to after_cliente_authentication_url
    else
      # El mensaje nombra las dos formas: si dijera solo "correo", el cliente que
      # entro con su codigo creeria que tecleo mal el campo equivocado.
      redirect_to new_session_path, alert: "Correo, codigo o contrasena incorrectos."
    end
  end

  def destroy
    terminate_session if authenticated?
    terminate_cliente_session if cliente_authenticated?
    redirect_to new_session_path
  end
end
