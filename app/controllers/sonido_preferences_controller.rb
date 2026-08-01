# PR-9.c: persiste las preferencias de sonido por usuario. Mismo patrón que
# ThemePreferencesController / SidebarPreferencesController — llamado vía
# fetch desde el Stimulus `sonido_config` cuando el operario mueve el slider
# o apaga los sonidos.
class SonidoPreferencesController < ApplicationController
  def update
    return head :unauthorized unless Current.user

    attrs = {}
    attrs[:sonido_habilitado] = bool_param(:habilitado) if params.key?(:habilitado)
    attrs[:sonido_volumen]    = params[:volumen].to_i.clamp(0, 100) if params.key?(:volumen)
    Current.user.update(attrs) if attrs.any?

    head :ok
  end

  private

  def bool_param(key)
    ActiveModel::Type::Boolean.new.cast(params[key])
  end
end
