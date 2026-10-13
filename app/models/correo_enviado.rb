# PR-C31.10 · Un correo que el sistema intentó mandar, y cómo le fue.
#
# Lo pidió Yusef para SAC (`C31-20`): *"todos los correos enviados, **lo que
# falló**"*. Lo escribe `ApplicationMailer` en cada entrega; nadie más.
#
# Sin `has_paper_trail` a propósito: es en sí mismo un registro y solo se
# agrega. Versionarlo sería guardar dos veces lo mismo.
class CorreoEnviado < ApplicationRecord
  ESTADOS = %w[enviado fallido].freeze

  belongs_to :cliente, optional: true

  validates :mailer, :accion, :enviado_at, presence: true
  validates :estado, inclusion: { in: ESTADOS }

  scope :recientes, -> { order(created_at: :desc, id: :desc) }
  scope :fallidos, -> { where(estado: "fallido") }

  def fallido?
    estado == "fallido"
  end
end
