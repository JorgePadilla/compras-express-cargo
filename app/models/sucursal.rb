class Sucursal < ApplicationRecord
  self.table_name = "sucursales"

  UBICACIONES = %w[miami honduras otros].freeze

  has_many :paquetes, dependent: :restrict_with_error
  has_many :sub_localidades, dependent: :destroy  # PR-D1.c: bodegas internas

  validates :codigo, presence: true, uniqueness: { case_sensitive: false }
  validates :nombre, presence: true
  validates :codigo_recepcion_prefix, presence: true, uniqueness: { case_sensitive: false },
            format: { with: /\A[A-Z]{1,4}\z/, message: "solo mayusculas (1-4 letras)" }
  validates :ubicacion, inclusion: { in: UBICACIONES, allow_nil: true }

  normalizes :codigo, with: ->(c) { c.to_s.strip.upcase }
  normalizes :codigo_recepcion_prefix, with: ->(p) { p.to_s.strip.upcase }

  scope :activas, -> { where(activo: true) }
  scope :ordered, -> { order(:nombre) }

  def to_s
    nombre
  end
end
