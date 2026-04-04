module Cuenta
  class BaseController < ActionController::Base
    include ClienteAuthentication

    layout "cuenta"

    allow_browser versions: :modern
  end
end
