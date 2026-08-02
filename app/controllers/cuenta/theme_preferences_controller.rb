module Cuenta
  class ThemePreferencesController < BaseController
    def update
      return head :unauthorized unless Current.cliente

      tema = params[:tema].presence_in(%w[light dark]) || nil
      Current.cliente.update(tema: tema)

      respond_to do |format|
        format.json { render json: { tema: Current.cliente.tema } }
        format.html { redirect_to(request.referer || cuenta_root_path) }
      end
    end
  end
end
