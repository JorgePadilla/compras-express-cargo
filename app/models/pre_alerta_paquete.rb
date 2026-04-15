class PreAlertaPaquete < ApplicationRecord
  belongs_to :pre_alerta
  belongs_to :paquete, optional: true

  validates :tracking, presence: true, uniqueness: { scope: :pre_alerta_id, case_sensitive: false }
  validates :tracking, format: { with: /\A[A-Z0-9]+\z/, message: "solo permite letras y numeros" },
                       allow_blank: true
  validates :descripcion, presence: true

  scope :sin_vincular, -> { where(paquete_id: nil) }
  scope :vinculados, -> { where.not(paquete_id: nil) }

  before_validation :set_default_fecha
  before_validation :normalize_tracking

  # Links unlinked pre_alerta_paquetes by tracking to a given paquete.
  # Advances parent pre_alerta estado to "recibido" if still in pre_alerta state.
  # Returns number of rows linked.
  def self.link_tracking!(tracking, paquete)
    normalized = tracking.strip.upcase
    rows = sin_vincular.where("UPPER(tracking) = ?", normalized)
    pre_alerta_ids = rows.pluck(:pre_alerta_id).uniq
    count = rows.update_all(paquete_id: paquete.id)

    if count > 0
      PreAlerta.where(id: pre_alerta_ids, estado: "pre_alerta").find_each do |pa|
        pa.update!(estado: "recibido")
      end
    end

    count
  end

  private

  def set_default_fecha
    self.fecha ||= Date.current
  end

  def normalize_tracking
    self.tracking = tracking.strip.upcase if tracking.present?
  end
end
