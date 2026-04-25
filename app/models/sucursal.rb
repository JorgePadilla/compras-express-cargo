class Sucursal < ApplicationRecord
  UBICACIONES = %w[miami honduras otros].freeze

  has_many :paquetes, dependent: :restrict_with_error

  validates :codigo, presence: true, uniqueness: { case_sensitive: false }
  validates :nombre, presence: true
  validates :codigo_recepcion_prefix, presence: true, uniqueness: { case_sensitive: false },
            format: { with: /\A[A-Z]{1,4}\z/, message: "solo mayusculas (1-4 letras)" }
  validates :ubicacion, inclusion: { in: UBICACIONES, allow_nil: true }

  normalizes :codigo, with: ->(c) { c.to_s.strip.upcase }
  normalizes :codigo_recepcion_prefix, with: ->(p) { p.to_s.strip.upcase }

  scope :activas, -> { where(activo: true) }
  scope :ordered, -> { order(:nombre) }

  after_create :ensure_numero_recepcion_sequence
  after_destroy :drop_numero_recepcion_sequence

  def to_s
    nombre
  end

  # Nombre de la secuencia PG atomica para numero_recepcion de esta sucursal.
  def numero_recepcion_sequence_name
    "numero_recepcion_#{codigo_recepcion_prefix}_seq"
  end

  # Crea la secuencia SQL atomica si no existe. Idempotente. Se llama al
  # crear la sucursal via callback; tambien de forma defensiva desde
  # Paquete#generate_numero_recepcion para cubrir fixtures de tests y
  # escenarios donde la sucursal se creo via SQL raw (sin callbacks).
  def ensure_numero_recepcion_sequence
    self.class.connection.execute(
      "CREATE SEQUENCE IF NOT EXISTS #{numero_recepcion_sequence_name} START WITH 1"
    )
  end

  private

  def drop_numero_recepcion_sequence
    self.class.connection.execute(
      "DROP SEQUENCE IF EXISTS #{numero_recepcion_sequence_name}"
    )
  end
end
