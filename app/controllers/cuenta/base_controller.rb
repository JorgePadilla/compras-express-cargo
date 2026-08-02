module Cuenta
  class BaseController < ActionController::Base
    include ClienteAuthentication

    layout "cuenta"

    allow_browser versions: :modern

    private

    # Pagination: per_page sanitizado (igual que en ApplicationController).
    def per_page_sanitized
      n = params[:per].to_i
      return 25 if n <= 0
      n.clamp(10, 200)
    end
  end
end
