class CleanEmptyPreAlertasJob < ApplicationJob
  queue_as :default

  # Una pre-alerta que no se puede borrar no frena a las demás: se anota y se
  # sigue. Antes la primera que fallaba tumbaba el job entero, todas las
  # noches (2026-10-08, «Signos del servidor»: 32 fallidos).
  def perform
    count = 0
    fallas = []
    PreAlerta.activas.vacias.where(created_at: ...30.days.ago).find_each do |pa|
      pa.soft_delete!
      count += 1
    rescue ActiveRecord::ActiveRecordError => e
      fallas << "#{pa.numero_documento}: #{e.message}"
    end
    Rails.logger.info "[CleanEmptyPreAlertasJob] Soft-deleted #{count} empty pre-alertas"
    Rails.logger.warn "[CleanEmptyPreAlertasJob] No se pudieron borrar #{fallas.size}: #{fallas.join(' · ')}" if fallas.any?
  end
end
