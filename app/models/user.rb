class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Enums (string-backed for readable DB values)
  enum :rol, {
    admin: "admin",
    supervisor_miami: "supervisor_miami",
    digitador_miami: "digitador_miami",
    supervisor_caja: "supervisor_caja",
    supervisor_prefactura: "supervisor_prefactura",
    cajero: "cajero",
    sac: "sac",
    entrega_despacho: "entrega_despacho"
  }

  enum :ubicacion, {
    miami: "miami",
    honduras: "honduras"
  }

  # Validations
  validates :nombre, presence: true
  validates :email_address, presence: true, uniqueness: true
  validates :rol, presence: true

  # Scopes
  scope :activos, -> { where(activo: true) }
  scope :por_rol, ->(rol) { where(rol: rol) }
  scope :en_ubicacion, ->(ubicacion) { where(ubicacion: ubicacion) }

  def nombre_completo
    nombre
  end
end
