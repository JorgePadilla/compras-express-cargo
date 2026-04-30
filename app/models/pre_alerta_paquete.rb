class PreAlertaPaquete < ApplicationRecord
  belongs_to :pre_alerta
  belongs_to :paquete, optional: true

  validates :tracking, presence: true, uniqueness: { scope: :pre_alerta_id, case_sensitive: false }
  # allow_blank: true avoids double error ("can't be blank" + format) when tracking is empty;
  # presence: true above already handles the blank case.
  validates :tracking, format: { with: /\A[A-Z0-9-]+\z/, message: "solo permite letras, números y guiones" },
                       allow_blank: true
  validates :descripcion, presence: true

  scope :sin_vincular, -> { where(paquete_id: nil) }
  scope :vinculados, -> { where.not(paquete_id: nil) }

  before_validation :set_default_fecha
  before_validation :normalize_tracking

  after_destroy_commit :soft_delete_pre_alerta_if_empty

  # Links unlinked pre_alerta_paquetes by tracking to a given paquete.
  # Advances parent pre_alerta estado to "recibido" if still in pre_alerta state.
  # Returns number of rows linked.
  #
  # PR-D1.e: ahora matchea contra el tracking PRINCIPAL del paquete y el
  # SECUNDARIO (cuando existe). Yusef pidió esto porque muchos paquetes
  # llegan con 2 trackings: el cliente pre-alerta con uno, el paquete
  # físico llega con el otro. Sin este match dual, la vinculación falla.
  def self.link_tracking!(tracking, paquete)
    argument_tracking  = tracking
    primary_tracking   = paquete.tracking
    secondary_tracking = paquete.tracking_secundario

    candidatos = [ argument_tracking, primary_tracking, secondary_tracking ]
                   .compact_blank
                   .map { |t| t.to_s.strip.upcase }
                   .uniq
    return 0 if candidatos.empty?

    rows = sin_vincular.where("UPPER(tracking) IN (?)", candidatos)
    pre_alerta_ids = rows.pluck(:pre_alerta_id).uniq
    count = rows.update_all(paquete_id: paquete.id)

    if count > 0
      pre_alertas = PreAlerta.where(id: pre_alerta_ids)

      # PR-D2: snapshot de notas_grupo de pre-alerta consolidada al
      # paquete (notas_consolidacion). Solo si el paquete no las tiene
      # ya (no sobrescribir si admin/sac las editó).
      if paquete.notas_consolidacion.blank?
        notas = pre_alertas.where(consolidado: true)
                          .where.not(notas_grupo: [ nil, "" ])
                          .pluck(:notas_grupo)
                          .compact_blank
                          .uniq
        if notas.any?
          paquete.update_column(:notas_consolidacion, notas.join("\n\n"))
        end
      end

      pre_alertas.where(estado: "pre_alerta").find_each do |pa|
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

  def soft_delete_pre_alerta_if_empty
    pa = pre_alerta
    return unless pa
    return if pa.deleted_at.present?
    pa.soft_delete! if pa.pre_alerta_paquetes.reload.empty?
  end
end
