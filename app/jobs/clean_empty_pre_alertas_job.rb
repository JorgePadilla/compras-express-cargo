class CleanEmptyPreAlertasJob < ApplicationJob
  queue_as :default

  def perform
    count = 0
    PreAlerta.activas.vacias.where(created_at: ...30.days.ago).find_each do |pa|
      pa.soft_delete!
      count += 1
    end
    Rails.logger.info "[CleanEmptyPreAlertasJob] Soft-deleted #{count} empty pre-alertas"
  end
end
