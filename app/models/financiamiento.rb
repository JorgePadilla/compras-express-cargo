class Financiamiento < ApplicationRecord
  include CurrencyAware

  ESTADOS = %w[activo completado cancelado].freeze
  FRECUENCIAS = %w[semanal quincenal mensual].freeze

  belongs_to :venta
  belongs_to :cliente
  belongs_to :creado_por, class_name: "User", optional: true
  has_many :financiamiento_cuotas, dependent: :destroy

  validates :numero, presence: true, uniqueness: { case_sensitive: false }
  validates :estado, presence: true, inclusion: { in: ESTADOS }
  validates :numero_cuotas, numericality: { greater_than: 0 }
  validates :monto_total, numericality: { greater_than: 0 }
  validates :monto_cuota, numericality: { greater_than: 0 }
  validates :frecuencia, presence: true, inclusion: { in: FRECUENCIAS }
  validates :fecha_inicio, presence: true

  before_validation :generate_numero, on: :create, if: -> { numero.blank? }
  before_validation :calculate_monto_cuota, on: :create

  scope :activos,      -> { where(estado: "activo") }
  scope :completados,  -> { where(estado: "completado") }
  scope :recientes,    -> { order(created_at: :desc) }
  scope :by_cliente,   ->(id) { where(cliente_id: id) }
  scope :by_estado,    ->(estado) { where(estado: estado) }
  scope :buscar, ->(term) {
    left_joins(:cliente).where(
      "financiamientos.numero ILIKE :q OR clientes.codigo ILIKE :q OR clientes.nombre ILIKE :q",
      q: "%#{sanitize_sql_like(term)}%"
    )
  }

  ESTADOS.each do |estado|
    define_method("#{estado}?") { self.estado == estado }
  end

  def save(**args, &block)
    super
  rescue ActiveRecord::RecordNotUnique => e
    raise unless new_record? && e.message.include?("numero") && (@_numero_retries ||= 0) < 3
    @_numero_retries += 1
    self.numero = nil
    generate_numero
    retry
  end

  def generar_cuotas!
    return if financiamiento_cuotas.any?

    transaction do
      numero_cuotas.times do |i|
        fecha = case frecuencia
                when "semanal"    then fecha_inicio + (i * 7).days
                when "quincenal"  then fecha_inicio + (i * 15).days
                when "mensual"    then fecha_inicio + i.months
                end

        financiamiento_cuotas.create!(
          numero_cuota: i + 1,
          monto: monto_cuota,
          fecha_vencimiento: fecha,
          estado: "pendiente"
        )
      end
    end
  end

  def verificar_completado!
    return unless activo?

    if financiamiento_cuotas.where.not(estado: "pagada").empty?
      update!(estado: "completado")
    end
  end

  def cancelar!
    return false unless activo?
    update!(estado: "cancelado")
    true
  end

  def monto_pagado
    financiamiento_cuotas.where(estado: "pagada").sum(:monto)
  end

  def monto_pendiente
    monto_total.to_d - monto_pagado.to_d
  end

  def progreso_porcentaje
    return 0 if numero_cuotas.zero?
    ((financiamiento_cuotas.where(estado: "pagada").count.to_f / numero_cuotas) * 100).round
  end

  def self.marcar_cuotas_vencidas!
    FinanciamientoCuota.where(estado: "pendiente")
                       .where("fecha_vencimiento < ?", Date.current)
                       .update_all(estado: "vencida")
  end

  private

  def generate_numero
    next_number = (self.class.where("numero LIKE 'FN-%'")
                    .maximum(Arel.sql("CAST(SUBSTRING(numero FROM 4) AS INTEGER)")) || 0) + 1
    self.numero = "FN-#{next_number.to_s.rjust(6, '0')}"
  end

  def calculate_monto_cuota
    if monto_total.present? && numero_cuotas.present? && numero_cuotas > 0 && monto_cuota.blank?
      self.monto_cuota = (monto_total.to_d / numero_cuotas).round(2)
    end
  end
end
