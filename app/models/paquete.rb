class Paquete < ApplicationRecord
  belongs_to :cliente
  belongs_to :manifiesto, optional: true
  belongs_to :tipo_envio, optional: true
  belongs_to :user, optional: true

  enum :estado, {
    recibido: "recibido",
    etiquetado: "etiquetado",
    en_manifiesto: "en_manifiesto",
    enviado: "enviado",
    en_aduana: "en_aduana",
    en_bodega_hn: "en_bodega_hn",
    pre_facturado: "pre_facturado",
    facturado: "facturado",
    entregado: "entregado",
    anulado: "anulado"
  }

  validates :tracking, presence: true
  validates :guia, presence: true, uniqueness: { case_sensitive: false }
  validates :estado, presence: true

  scope :activos, -> { where.not(estado: %w[anulado entregado]) }
  scope :buscar, ->(term) {
    left_joins(:cliente).where(
      "paquetes.tracking ILIKE :q OR paquetes.guia ILIKE :q OR clientes.codigo ILIKE :q OR clientes.nombre ILIKE :q",
      q: "%#{sanitize_sql_like(term)}%"
    )
  }
  scope :by_estado, ->(estado) { where(estado: estado) }
  scope :by_tipo_envio, ->(tipo_envio_id) { where(tipo_envio_id: tipo_envio_id) }
  scope :by_cliente, ->(cliente_id) { where(cliente_id: cliente_id) }
  scope :recibidos_hoy, -> { where(fecha_recibido_miami: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :sin_manifiesto, -> { where(manifiesto_id: nil).where.not(estado: %w[anulado entregado]) }

  before_validation :generate_guia, on: :create, if: -> { guia.blank? }
  before_save :set_fecha_recibido, if: -> { fecha_recibido_miami.blank? && new_record? }
  before_save :calculate_peso_volumetrico
  before_save :calculate_peso_cobrar

  def estado_terminal?
    entregado? || anulado?
  end

  private

  def generate_guia
    last_number = self.class
      .where("guia LIKE 'PQ-%'")
      .pluck(:guia)
      .map { |g| g.sub("PQ-", "").to_i }
      .max || 0
    self.guia = "PQ-#{(last_number + 1).to_s.rjust(6, '0')}"
  end

  def set_fecha_recibido
    self.fecha_recibido_miami = Time.current
  end

  def calculate_peso_volumetrico
    if alto.present? && largo.present? && ancho.present?
      self.peso_volumetrico = (alto * largo * ancho / 166.0).round(2)
    end
  end

  def calculate_peso_cobrar
    if peso.present? || peso_volumetrico.present?
      self.peso_cobrar = [peso || 0, peso_volumetrico || 0].max
    end
  end
end
