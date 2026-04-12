class Recibo < ApplicationRecord
  include CurrencyAware

  belongs_to :venta
  belongs_to :pago
  belongs_to :cliente

  validates :numero, presence: true, uniqueness: { case_sensitive: false }
  validates :monto, numericality: { greater_than: 0 }

  before_validation :generate_numero, on: :create, if: -> { numero.blank? }

  scope :recientes,  -> { order(created_at: :desc) }
  scope :by_cliente, ->(id) { where(cliente_id: id) }

  def save(**args, &block)
    super
  rescue ActiveRecord::RecordNotUnique => e
    raise unless new_record? && e.message.include?("numero") && (@_numero_retries ||= 0) < 3
    @_numero_retries += 1
    self.numero = nil
    generate_numero
    retry
  end

  private

  def generate_numero
    next_number = (self.class.where("numero LIKE 'RE-%'")
                    .maximum(Arel.sql("CAST(SUBSTRING(numero FROM 4) AS INTEGER)")) || 0) + 1
    self.numero = "RE-#{next_number.to_s.rjust(6, '0')}"
  end
end
