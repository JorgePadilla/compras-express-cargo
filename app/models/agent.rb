class Agent < ApplicationRecord
  has_many :warehouse_receipts, dependent: :restrict_with_error

  validates :codigo, presence: true, uniqueness: { case_sensitive: false }
  validates :nombre, presence: true

  normalizes :codigo, with: ->(c) { c.to_s.strip.upcase }

  scope :activos, -> { where(activo: true) }
  scope :ordered, -> { order(:position, :nombre) }

  def to_s
    "#{codigo} · #{nombre}"
  end
end
