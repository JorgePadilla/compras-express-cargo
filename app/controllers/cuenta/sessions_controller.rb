module Cuenta
  class SessionsController < BaseController
    allow_unauthenticated_cliente_access only: %i[new create]
    rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
      redirect_to new_cuenta_session_path, alert: "Demasiados intentos. Intenta de nuevo mas tarde."
    }

    def new
    end

    def create
      if cliente = Cliente.activos.authenticate_by(email: params[:email], password: params[:password])
        start_new_cliente_session_for(cliente)
        redirect_to after_cliente_authentication_url
      else
        redirect_to new_cuenta_session_path, alert: "Correo o contrasena incorrectos."
      end
    end

    def destroy
      terminate_cliente_session
      redirect_to new_cuenta_session_path
    end
  end
end
