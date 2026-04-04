class PreAlertaPaquete < ApplicationRecord
  belongs_to :pre_alerta
  belongs_to :paquete, optional: true

  validates :tracking, presence: true
  validates :tracking, uniqueness: { scope: :pre_alerta_id, case_sensitive: false }

  scope :sin_vincular, -> { where(paquete_id: nil) }
  scope :vinculados, -> { where.not(paquete_id: nil) }

  before_save :normalize_tracking

  private

  def normalize_tracking
    self.tracking = tracking.strip.upcase if tracking.present?
  end
end
