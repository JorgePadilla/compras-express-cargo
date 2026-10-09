class TipoEnvio < ApplicationRecord
  has_paper_trail  # PR-D7: audit log — precio_libra y SLA cambian, afecta facturación

  # C21-03: `manifiesto_tipo_envios` es una tabla de enlace, no datos propios —
  # la fila dice «este manifiesto lleva este tipo». Si el tipo desaparece, el
  # enlace no tiene de qué hablar y se va con él. En la práctica los tipos se
  # **desactivan** (`activo`), no se borran; sin este `dependent` la FK bloquea
  # incluso ese borrado excepcional.
  has_many :manifiesto_tipo_envios, dependent: :destroy
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
