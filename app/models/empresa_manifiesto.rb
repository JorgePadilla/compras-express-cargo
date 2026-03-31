class EmpresaManifiesto < ApplicationRecord
  validates :nombre, presence: true

  scope :activos, -> { where(activo: true) }
end
