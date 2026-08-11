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
    # RP-20: la variante NO se sanea acá. El volumen se puede recortar a un
    # rango; una variante inventada no tiene a qué recortarse, así que la
    # rechaza la validación del modelo y el `update` devuelve false sin guardar
    # nada. Un default silencioso escondería que el JS mandó basura.
    attrs[:sonido_error_variante] = params[:variante].to_s if params.key?(:variante)

    return head :unprocessable_entity if attrs.any? && !Current.user.update(attrs)

    head :ok
  end

  private

  def bool_param(key)
    ActiveModel::Type::Boolean.new.cast(params[key])
  end
end
