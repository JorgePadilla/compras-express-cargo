# PR-D1.a fix: paper_trail v17 instala `PaperTrail::Model` (macro
# `has_paper_trail`) en `ActiveRecord::Base` via Railtie + lazy
# `on_load(:active_record)`. En dev con autoload de Zeitwerk, ese
# hook puede dispararse después de que un modelo intente usar
# `has_paper_trail` — produciendo `NameError: undefined local
# variable or method 'has_paper_trail' for class Paquete`.
#
# Solución: forzar el require de los archivos de paper_trail antes
# de cualquier autoload de modelos, garantizando que el macro esté
# definido al evaluar la primera clase hija.
require "paper_trail/has_paper_trail"
require "paper_trail/frameworks/rails/controller"

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.include(PaperTrail::Model) unless ActiveRecord::Base.include?(PaperTrail::Model)
end

ActiveSupport.on_load(:action_controller) do
  unless ActionController::Base.include?(PaperTrail::Rails::Controller)
    ActionController::Base.include(PaperTrail::Rails::Controller)
  end
end
