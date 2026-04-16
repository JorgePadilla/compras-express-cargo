class Paquete < ApplicationRecord
  belongs_to :cliente
  belongs_to :manifiesto, optional: true
  belongs_to :tipo_envio, optional: true
  belongs_to :user, optional: true
  belongs_to :pre_factura, optional: true
  belongs_to :venta, optional: true
  belongs_to :entrega, optional: true
  has_many :pre_alerta_paquetes, dependent: :nullify
  has_many :nota_debito_items,  dependent: :nullify
  has_many :nota_credito_items, dependent: :nullify

  enum :estado, {
    recibido_miami: "recibido_miami",
    empacado: "empacado",
    enviado_honduras: "enviado_honduras",
    en_aduana: "en_aduana",
    disponible_entrega: "disponible_entrega",
    pre_facturado: "pre_facturado",
    facturado: "facturado",
    en_reparto: "en_reparto",
    entregado: "entregado",
    retenido: "retenido",
    retornado: "retornado",
    desechado: "desechado",
    anulado: "anulado"
  }

  validates :tracking, presence: true
  validates :guia, presence: true, uniqueness: { case_sensitive: false }
  validates :estado, presence: true
  validates :peso, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :alto, :largo, :ancho, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :activos, -> { where.not(estado: %w[anulado entregado retornado desechado]) }
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
  scope :sin_manifiesto, -> { where(manifiesto_id: nil).where.not(estado: %w[anulado entregado retornado desechado]) }
  scope :facturables, -> { where(estado: "disponible_entrega", pre_factura_id: nil, venta_id: nil) }
  scope :entregables, -> { where(estado: "facturado", entrega_id: nil) }
  # Paquetes sin vincular a ninguna pre_alerta_paquete (sueltos en bodega)
  scope :sin_pre_alerta, -> {
    left_joins(:pre_alerta_paquetes).where(pre_alerta_paquetes: { id: nil })
  }

  before_validation :generate_guia, on: :create, if: -> { guia.blank? }
  before_save :set_fecha_recibido, if: -> { fecha_recibido_miami.blank? && new_record? }
  before_save :calculate_peso_volumetrico
  before_save :calculate_peso_cobrar
  after_save :sync_pre_alerta_estados, if: :saved_change_to_estado?

  def estado_terminal?
    entregado? || anulado? || retornado? || desechado?
  end

  def save(**args, &block)
    super
  rescue ActiveRecord::RecordNotUnique => e
    raise unless new_record? && e.message.include?("guia") && (@_guia_retries ||= 0) < 3
    @_guia_retries += 1
    self.guia = nil
    generate_guia
    retry
  end

  private

  def sync_pre_alerta_estados
    pre_alerta_paquetes.includes(:pre_alerta).each do |pap|
      pap.pre_alerta&.actualizar_estado_from_paquetes!
    end
  end

  def generate_guia
    next_number = (self.class.where("guia LIKE 'PQ-%'").maximum(Arel.sql("CAST(SUBSTRING(guia FROM 4) AS INTEGER)")) || 0) + 1
    self.guia = "PQ-#{next_number.to_s.rjust(6, '0')}"
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
