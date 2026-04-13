class AperturaCaja < ApplicationRecord
  self.table_name = "aperturas_caja"

  ESTADOS = %w[abierta cerrada].freeze

  belongs_to :abierta_por, class_name: "User"
  belongs_to :cerrada_por, class_name: "User", optional: true
  has_many :ingresos_caja, foreign_key: :apertura_caja_id, dependent: :restrict_with_error
  has_many :egresos_caja, foreign_key: :apertura_caja_id, dependent: :restrict_with_error
  has_many :pagos, foreign_key: :apertura_caja_id, dependent: :nullify

  validates :numero, presence: true, uniqueness: { case_sensitive: false }
  validates :fecha, presence: true, uniqueness: { message: "ya existe una apertura para esta fecha" }
  validates :estado, presence: true, inclusion: { in: ESTADOS }
  validates :monto_apertura, numericality: { greater_than_or_equal_to: 0 }

  before_validation :generate_numero, on: :create, if: -> { numero.blank? }

  scope :recientes, -> { order(fecha: :desc) }

  ESTADOS.each do |estado|
    define_method("#{estado}?") { self.estado == estado }
  end

  def self.del_dia
    find_by(fecha: Date.current)
  end

  def self.abierta_hoy?
    del_dia&.abierta?
  end

  def total_esperado
    monto_apertura.to_d + total_pagos.to_d + total_ingresos.to_d - total_egresos.to_d
  end

  def recalcular_totales!
    update!(
      total_pagos: pagos.where(estado: "completado").sum(:monto),
      total_ingresos: ingresos_caja.sum(:monto),
      total_egresos: egresos_caja.sum(:monto)
    )
  end

  def cerrar!(monto_cierre:, user:, notas: nil)
    return false unless abierta?

    recalcular_totales!
    reload

    update!(
      estado: "cerrada",
      monto_cierre: monto_cierre,
      diferencia: BigDecimal(monto_cierre.to_s) - total_esperado,
      notas_cierre: notas,
      cerrada_por: user,
      cerrada_at: Time.current
    )
    true
  end

  private

  def generate_numero
    next_number = self.class.connection.select_value("SELECT nextval('aperturas_caja_numero_seq')")
    self.numero = "AC-#{next_number.to_s.rjust(6, '0')}"
  end
end
