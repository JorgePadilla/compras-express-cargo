class Tarea < ApplicationRecord
  belongs_to :paquete
  belongs_to :asignado_a, class_name: "User", optional: true
  belongs_to :completado_por, class_name: "User", optional: true
  has_one :reempaque, dependent: :nullify

  enum :estado, {
    pendiente: "pendiente",
    en_proceso: "en_proceso",
    realizada: "realizada"
  }

  validates :titulo, presence: true
  validates :estado, presence: true

  scope :abiertas, -> { where.not(estado: "realizada") }
  scope :por_paquete, ->(paquete_id) { where(paquete_id: paquete_id) }

  def completar!(user)
    update!(estado: "realizada", completado_por: user, completada_en: Time.current)
  end

  def reabrir!
    update!(estado: "pendiente", completado_por: nil, completada_en: nil)
  end

  def iniciar!(user = nil)
    update!(estado: "en_proceso", asignado_a: asignado_a || user)
  end
end
