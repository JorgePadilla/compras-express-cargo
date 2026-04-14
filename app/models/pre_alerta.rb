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
  validates :titulo, presence: true
  validate :respect_max_paquetes_por_accion

  accepts_nested_attributes_for :pre_alerta_paquetes, allow_destroy: true,
    reject_if: ->(attrs) {
      attrs["tracking"].blank? &&
      attrs["descripcion"].blank? &&
      attrs["instrucciones"].blank?
    }

  scope :activas, -> { where(deleted_at: nil).where.not(estado: "anulado") }
  scope :buscar, ->(term) {
    left_joins(:cliente).where(
      "pre_alertas.numero_documento ILIKE :q OR clientes.codigo ILIKE :q OR clientes.nombre ILIKE :q OR pre_alertas.titulo ILIKE :q OR pre_alertas.proveedor ILIKE :q",
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

  before_validation :assign_default_tipo_envio, on: :create
  before_validation :generate_numero_documento, on: :create, if: -> { numero_documento.blank? }

  PAQUETE_TO_PRE_ALERTA_ESTADO = {
    "recibido_miami"     => "recibido",
    "empacado"           => "recibido",
    "enviado_honduras"   => "enviado",
    "en_aduana"          => "en_aduana",
    "disponible_entrega" => "disponible",
    "pre_facturado"      => "disponible",
    "facturado"          => "facturado",
    "en_reparto"         => "facturado",
    "entregado"          => "facturado"
  }.freeze

  ESTADO_PIPELINE = %w[pre_alerta recibido enviado en_aduana disponible facturado].freeze

  def actualizar_estado_from_paquetes!
    return if anulado?

    paquetes = pre_alerta_paquetes.where.not(paquete_id: nil).includes(:paquete).filter_map(&:paquete)
    return if paquetes.empty?

    mapped = paquetes.filter_map { |p| PAQUETE_TO_PRE_ALERTA_ESTADO[p.estado] }
    return if mapped.empty?

    min_idx = mapped.map { |e| ESTADO_PIPELINE.index(e) }.compact.min
    return if min_idx.nil?

    cur_idx = ESTADO_PIPELINE.index(estado)
    return if cur_idx.nil? || min_idx <= cur_idx

    update!(estado: ESTADO_PIPELINE[min_idx])
  end

  def anular!
    update!(estado: "anulado")
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def vacia?
    pre_alerta_paquetes.empty?
  end

  def consolidando?
    consolidado? && !finalizado?
  end

  def append_historial!(entry)
    current = historial.to_s
    new_historial = current.present? ? "#{current}\n#{entry}" : entry
    update_column(:historial, new_historial)
  end

  def tipo_envio_descripcion
    return "" unless tipo_envio
    modalidad = tipo_envio.modalidad&.capitalize || "—"
    tipo_envio.con_reempaque ? "#{modalidad} con Reempaque" : "#{modalidad} sin Reempaque"
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

  def assign_default_tipo_envio
    return if tipo_envio_id.present? || tipo_envio.present?
    self.tipo_envio = TipoEnvio.activos.find_by(codigo: "cer")
  end

  def respect_max_paquetes_por_accion
    return unless tipo_envio&.single_package?
    active_paquetes = pre_alerta_paquetes.reject(&:marked_for_destruction?)
    return if active_paquetes.size <= 1
    errors.add(:base, "#{tipo_envio.nombre} solo permite 1 paquete por pre-alerta")
  end

  def generate_numero_documento
    next_number = (self.class.where("numero_documento LIKE 'PA-%'")
      .maximum(Arel.sql("CAST(SUBSTRING(numero_documento FROM 4) AS INTEGER)")) || 0) + 1
    self.numero_documento = "PA-#{next_number.to_s.rjust(6, '0')}"
  end
end
