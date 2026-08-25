# Recuperar la clave. Sirve para los **dos** tipos de cuenta.
#
# PR-C7.37: hasta acá era solo de `User`, así que el link "Olvidé mi contraseña"
# del login **no hacía nada** para un cliente — y encima contestaba *"si existe
# una cuenta con ese correo"*, o sea que fallaba en silencio. Un cliente sin
# clave no tenía forma de conseguir una: el admin tampoco podía ponérsela.
#
# Yusef, 2026-08-19: *"en la parte del cliente me falta todo eso: cómo cambiar
# contraseña, habilitar acceso a la plataforma"*.
class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_cuenta_by_token, only: %i[ edit update ]

  def new
  end

  def create
    identificador = params[:email_address].to_s.strip

    # Los clientes se buscan por correo **y por código**, igual que al entrar. Si
    # solo se mirara el correo, el cliente que Yusef describe —*"es que yo no
    # tengo correo"*— quedaría afuera del único camino que existe para él.
    if user = User.find_by(email_address: identificador)
      PasswordsMailer.reset(user).deliver_later
    elsif (cliente = Cliente.para_recuperar(identificador))&.email.present?
      PasswordsMailer.reset_cliente(cliente).deliver_later
    end

    # El mensaje no confirma ni desmiente que la cuenta exista, pero sí dice qué
    # hacer cuando no hay correo a dónde mandar nada — que en Honduras es la
    # mitad de los casos y antes dejaba al cliente sin salida.
    redirect_to new_session_path,
                notice: "Si esa cuenta existe y tiene correo, ahí van las instrucciones. " \
                        "Si el cliente no tiene correo, la clave se la pone la sucursal desde su ficha."
  end

  def edit
  end

  def update
    if guardar_clave
      redirect_to new_session_path, notice: "Contrasena actualizada exitosamente."
    else
      redirect_to edit_password_path(params[:token]),
                  alert: @cuenta.errors.full_messages.to_sentence.presence || "Las contrasenas no coinciden."
    end
  end

  private

    # El cliente pasa por `cambiar_clave` y el empleado no, porque solo `Cliente`
    # lleva `clave_actualizada_at` — la columna que deja la huella en la bitácora
    # de que esa clave se tocó (`password_digest` está en el `skip` de paper_trail).
    def guardar_clave
      if @cuenta.is_a?(Cliente)
        @cuenta.cambiar_clave(params[:password], params[:password_confirmation])
      else
        @cuenta.update(params.permit(:password, :password_confirmation))
      end
    end

    def set_cuenta_by_token
      @cuenta = User.find_by_password_reset_token(params[:token]) ||
                Cliente.find_by_password_reset_token(params[:token])
      return if @cuenta

      redirect_to new_password_path, alert: "El enlace de recuperacion es invalido o ha expirado."
    end
end
