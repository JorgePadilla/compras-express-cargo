class ThemePreferencesController < ApplicationController
  def update
    return head :unauthorized unless Current.user

    tema = params[:tema].presence_in(%w[light dark]) || nil
    Current.user.update(tema: tema)

    respond_to do |format|
      format.json { render json: { tema: Current.user.tema } }
      format.html { redirect_to(request.referer || root_path) }
    end
  end
end
