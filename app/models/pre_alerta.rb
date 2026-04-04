class PreAlerta < ApplicationRecord
  self.table_name = "pre_alertas"

  belongs_to :cliente
  belongs_to :tipo_envio
  has_many :pre_alerta_paquetes, dependent: :destroy

  enum :estado, {
    pre_alerta: "pre_alerta",
    recibido: "recibido",
    enviado: "enviado",
    en_aduana: "en_aduana",
    disponible: "disponible",
    facturado: "facturado",
    anulado: "anulado"
  }

  enum :creado_por_tipo, {
    cliente: "cliente",
    usuario: "usuario"
  }, prefix: :creado_por

  validates :numero_documento, presence: true, uniqueness: { case_sensitive: false }
  validates :estado, presence: true

  accepts_nested_attributes_for :pre_alerta_paquetes, allow_destroy: true,
    reject_if: ->(attrs) { attrs["tracking"].blank? }

  scope :activas, -> { where(deleted_at: nil).where.not(estado: "anulado") }
  scope :buscar, ->(term) {
    left_joins(:cliente).where(
      "pre_alertas.numero_documento ILIKE :q OR clientes.codigo ILIKE :q OR clientes.nombre ILIKE :q",
      q: "%#{sanitize_sql_like(term)}%"
    )
  }
  scope :by_estado, ->(estado) { where(estado: estado) }
  scope :by_cliente, ->(cliente_id) { where(cliente_id: cliente_id) }
  scope :by_tipo_envio, ->(tipo_envio_id) { where(tipo_envio_id: tipo_envio_id) }
  scope :recientes, -> { order(created_at: :desc) }
  scope :vacias, -> { left_joins(:pre_alerta_paquetes).where(pre_alerta_paquetes: { id: nil }) }
  scope :solo_anulados, -> { where(estado: "anulado") }
  scope :soft_deleted, -> { where.not(deleted_at: nil) }

  before_validation :generate_numero_documento, on: :create, if: -> { numero_documento.blank? }

  def anular!
    update!(estado: "anulado")
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def vacia?
    pre_alerta_paquetes.empty?
  end

  def save(**args, &block)
    super
  rescue ActiveRecord::RecordNotUnique => e
    raise unless new_record? && e.message.include?("numero_documento") && (@_doc_retries ||= 0) < 3
    @_doc_retries += 1
    self.numero_documento = nil
    generate_numero_documento
    retry
  end

  private

  def generate_numero_documento
    next_number = (self.class.where("numero_documento LIKE 'PA-%'")
      .maximum(Arel.sql("CAST(SUBSTRING(numero_documento FROM 4) AS INTEGER)")) || 0) + 1
    self.numero_documento = "PA-#{next_number.to_s.rjust(6, '0')}"
  end
end
