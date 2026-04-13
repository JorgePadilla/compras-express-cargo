class MarcarCotizacionesExpiradasJob < ApplicationJob
  queue_as :default

  def perform
    Cotizacion.marcar_expiradas!
  end
end
