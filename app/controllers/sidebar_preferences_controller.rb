# Persiste las 3 preferencias del sidebar (collapsed / pinned / position)
# por usuario. Patrón análogo a ThemePreferencesController. Llamado vía
# fetch desde el Stimulus `sidebar_controller.js` cada vez que el usuario
# clickea pin / position toggle.
class SidebarPreferencesController < ApplicationController
  def update
    return head :unauthorized unless Current.user

    attrs = {}
    attrs[:sidebar_collapsed] = bool_param(:collapsed) if params.key?(:collapsed)
    attrs[:sidebar_pinned]    = bool_param(:pinned)    if params.key?(:pinned)
    attrs[:sidebar_position]  = params[:position] if params[:position].in?(%w[left right])
    Current.user.update(attrs) if attrs.any?

    head :ok
  end

  private

  def bool_param(key)
    ActiveModel::Type::Boolean.new.cast(params[key])
  end
end
