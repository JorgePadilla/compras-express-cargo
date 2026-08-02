# Términos y condiciones del Warehouse Receipt — versionables y bilingues.
# Cada `WarehouseReceipt` congela una `terms_version` para auditoría.
# Para una version dada, hay 2 filas: language="es" + language="en".
class Term < ApplicationRecord
  # PR-D7: audit log — versionado bilingüe de T&C.
  # Renombramos la asociación paper_trail porque `Term#version` ya es una
  # columna del modelo (la versión del documento legal), distinta del
  # concepto "versión histórica" de paper_trail.
  has_paper_trail versions: { name: :paper_versions }, version: :paper_version
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

  # Devuelve el body para la combinación version+language pedidos.
  #
  # Si la combinación exacta no existe, hace **fallback al término activo
  # más reciente DEL MISMO LANGUAGE** (no al absoluto más reciente). Esto
  # es intencional: si un WR antiguo congeló `terms_version="2025-01"` y
  # ese registro luego fue eliminado, mostrar el último activo del idioma
  # pedido es mejor que romper la vista o servir un body en otro idioma.
  # Si el negocio prefiere "absoluto más reciente sin filtrar por idioma",
  # cambiar aquí — pero entonces hay que asegurar que cada language tenga
  # siempre al menos una versión activa.
  def self.body_for(version:, language:)
    record = find_by(version: version, language: language)
    record ||= activos.where(language: language).order(effective_from: :desc).first
    record&.body
  end
end
