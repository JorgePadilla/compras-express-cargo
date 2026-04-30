# PR-D1.a: paper_trail v17 NO incluye `PaperTrail::Rails::Controller`
# en ActionController::Base automáticamente vía Railtie. Tenemos que
# requerir y usarlo explícitamente. El `require` en el top del archivo
# garantiza que el constant esté definido al evaluar la clase.
require "paper_trail/frameworks/rails/controller"

class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include PaperTrail::Rails::Controller

  allow_browser versions: :modern

  # paper_trail audit log — registra qué usuario disparó cada cambio.
  # El callback se ejecuta antes de cada acción del controller.
  before_action :set_paper_trail_whodunnit

  private

  # paper_trail llama a este método para resolver el "whodunnit" de cada
  # version. Usamos `Current.user` (no `current_user`) porque la app
  # mantiene el usuario en thread-local via el concern Authentication.
  def user_for_paper_trail
    Current.user&.id
  end
end
