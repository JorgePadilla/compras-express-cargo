class ApplicationController < ActionController::Base
  include Authentication
  include Authorization

  allow_browser versions: :modern

  # PR-D1.a: paper_trail audit log — registra qué usuario disparó cada
  # cambio. El callback se ejecuta antes de cada acción del controller.
  before_action :set_paper_trail_whodunnit

  private

  # paper_trail llama a este método para resolver el "whodunnit" de cada
  # version. Usamos `Current.user` (no `current_user`) porque la app
  # mantiene el usuario en thread-local via el concern Authentication.
  def user_for_paper_trail
    Current.user&.id
  end
end
