class ApplicationController < ActionController::Base
  include Authentication
  include Authorization

  allow_browser versions: :modern

  # PR-D1.a: paper_trail audit log — registra qué usuario disparó cada
  # cambio. paper_trail hace su propio `include PaperTrail::Rails::Controller`
  # via Railtie + `ActiveSupport.on_load(:action_controller)`, así que
  # `set_paper_trail_whodunnit` está disponible en runtime aunque no
  # aparezca en `included_modules` al boot. Usamos lambda defensiva para
  # evitar el caso edge donde el hook aún no disparó.
  before_action -> { set_paper_trail_whodunnit if respond_to?(:set_paper_trail_whodunnit) }

  private

  # paper_trail llama a este método para resolver el "whodunnit" de cada
  # version. Usamos `Current.user` (no `current_user`) porque la app
  # mantiene el usuario en thread-local via el concern Authentication.
  def user_for_paper_trail
    Current.user&.id
  end

  # Pagination: per_page sanitizado (PR pagination redesign 2026-05-02).
  # Permite ?per=N en query, clamped a [10, 200], default 25.
  def per_page_sanitized
    n = params[:per].to_i
    return 25 if n <= 0
    n.clamp(10, 200)
  end
end
