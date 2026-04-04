class Manifiesto < ApplicationRecord
  belongs_to :empresa_manifiesto, optional: true
  belongs_to :user, optional: true
  has_many :paquetes, dependent: :nullify

  enum :estado, {
    creado: "creado",
    enviado: "enviado",
    en_aduana: "en_aduana",
    recibido: "recibido"
  }

  validates :numero, presence: true, uniqueness: { case_sensitive: false }
  validates :estado, presence: true

  scope :activos, -> { where(activo: true) }
  scope :buscar, ->(term) {
    where("numero ILIKE :q OR numero_guia ILIKE :q", q: "%#{sanitize_sql_like(term)}%")
  }
  scope :by_estado, ->(estado) { where(estado: estado) }

  before_validation :generate_numero, on: :create, if: -> { numero.blank? }

  def recalculate_totals!
    update!(
      cantidad_paquetes: paquetes.count,
      peso_total: paquetes.sum(:peso_cobrar),
      volumen_total: paquetes.sum(:volumen)
    )
  end

  def enviar!
    transaction do
      update!(estado: "enviado", fecha_enviado: Time.current)
      paquetes.update_all(estado: "enviado", fecha_enviado: Time.current)
    end
  end

  private

  def generate_numero
    last_number = self.class
      .where("numero LIKE 'MA-%'")
      .pluck(:numero)
      .map { |n| n.sub("MA-", "").to_i }
      .max || 0
    self.numero = "MA-#{(last_number + 1).to_s.rjust(6, '0')}"
  end
end
