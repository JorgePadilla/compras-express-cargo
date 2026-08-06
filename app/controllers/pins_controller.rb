# PR-13.c: donde el supervisor cambia su propio PIN de autorización.
#
# El admin asigna el inicial desde /users, pero mientras el supervisor no lo
# cambie el admin conoce el PIN con el que él autoriza — y ahí el registro de
# "quién autorizó" deja de probar nada. Esta pantalla es la que cierra eso.
#
# Se pide el PIN actual para cambiarlo: si alguien encuentra una sesión abierta
# no debería poder dejar al supervisor afuera y quedarse autorizando en su
# nombre.
class PinsController < ApplicationController
  before_action :require_rol_autorizante

  def edit
  end

  def update
    if Current.user.pin_digest.blank?
      return redirect_to edit_mi_pin_path,
                         alert: "Todavia no tenes PIN. Pedile a un administrador que te asigne uno."
    end

    unless Current.user.authenticate_pin(params.dig(:user, :pin_actual).to_s)
      Current.user.errors.add(:base, "El PIN actual no es correcto.")
      return render :edit, status: :unprocessable_entity
    end

    Current.user.assign_attributes(
      pin: params.dig(:user, :pin),
      pin_confirmation: params.dig(:user, :pin_confirmation),
      pin_cambiado_at: Time.current
    )

    if Current.user.save
      redirect_to root_path, notice: "PIN actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def require_rol_autorizante
    return if Current.user&.rol_autorizante?

    redirect_to root_path, alert: "Tu rol no usa PIN de autorizacion."
  end
end
