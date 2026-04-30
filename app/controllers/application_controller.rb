class ApplicationController < ActionController::Base
  include Authentication
  include Authorization

  # PR-D1.a: paper_trail v15+ ya no incluye el concern automáticamente
  # vía Railtie. Hay que incluirlo explícitamente para tener
  # `set_paper_trail_whodunnit` y los demás callbacks disponibles.
  include PaperTrail::Rails::Controller

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
