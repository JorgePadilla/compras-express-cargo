class Pago < ApplicationRecord
  METODOS = %w[efectivo tarjeta transferencia].freeze
  ESTADOS = %w[pendiente completado fallido reembolsado].freeze

  belongs_to :venta
  belongs_to :cliente
  belongs_to :registrado_por, class_name: "User", optional: true
  has_one :recibo, dependent: :restrict_with_error

  validates :monto, numericality: { greater_than: 0 }
  validates :metodo_pago, presence: true, inclusion: { in: METODOS }
  validates :estado, presence: true, inclusion: { in: ESTADOS }
  validates :moneda, presence: true

  scope :completados, -> { where(estado: "completado") }
  scope :recientes,   -> { order(created_at: :desc) }

  ESTADOS.each do |estado|
    define_method("#{estado}?") { self.estado == estado }
  end
end
