class TipoEnvio < ApplicationRecord
  validates :nombre, presence: true

  scope :activos, -> { where(activo: true) }
  scope :aereos, -> { where(modalidad: "aereo") }
  scope :maritimos, -> { where(modalidad: "maritimo") }

  def single_package?
    max_paquetes_por_accion == 1
  end

  def to_s
    nombre
  end
end
