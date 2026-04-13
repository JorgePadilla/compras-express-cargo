class MarcarCuotasVencidasJob < ApplicationJob
  queue_as :default

  def perform
    Financiamiento.marcar_cuotas_vencidas!
  end
end
