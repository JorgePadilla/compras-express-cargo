class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # PR-D1.a: paper_trail v17 incluye `PaperTrail::Model` (que provee el
  # macro `has_paper_trail`) en ActiveRecord::Base via Railtie con
  # `ActiveSupport.on_load(:active_record)`. En dev con autoload, ese
  # hook puede dispararse después de que un modelo ya intente usar
  # `has_paper_trail`, causando NameError. Incluirlo aquí explícitamente
  # garantiza que la macro esté disponible cuando se evalúan las clases
  # hijas (Paquete, Cliente, etc.).
  include PaperTrail::Model
end
