# Términos y condiciones del Warehouse Receipt — versionables y bilingues.
# Cada `WarehouseReceipt` congela una `terms_version` para auditoría.
# Para una version dada, hay 2 filas: language="es" + language="en".
class Term < ApplicationRecord
  LANGUAGES = %w[es en].freeze

  validates :version,        presence: true
  validates :language,       presence: true, inclusion: { in: LANGUAGES }
  validates :body,           presence: true
  validates :effective_from, presence: true
  validates :version,        uniqueness: { scope: :language }

  scope :activos, -> { where(activo: true) }
  scope :for_version, ->(v) { where(version: v) }
  scope :for_language, ->(lang) { where(language: lang) }

  def self.current_version
    activos.order(effective_from: :desc, version: :desc).pick(:version)
  end

  # Devuelve el body de la version+language pedidos. Cae a la version activa
  # más reciente si la pedida no existe.
  def self.body_for(version:, language:)
    record = find_by(version: version, language: language)
    record ||= activos.where(language: language).order(effective_from: :desc).first
    record&.body
  end
end
