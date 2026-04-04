class Cliente < ApplicationRecord
  has_secure_password validations: false

  belongs_to :categoria_precio, optional: true
  has_many :paquetes, dependent: :restrict_with_error
  has_many :cliente_sessions, dependent: :destroy
  has_many :pre_alertas, dependent: :restrict_with_error

  validates :codigo, presence: true, uniqueness: { case_sensitive: false }
  validates :nombre, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :activos, -> { where(activo: true) }
  scope :buscar, ->(term) {
    where("codigo ILIKE :q OR nombre ILIKE :q OR apellido ILIKE :q OR email ILIKE :q",
          q: "%#{sanitize_sql_like(term)}%")
  }

  before_validation :generate_codigo, on: :create, if: -> { codigo.blank? }

  def nombre_completo
    [nombre, apellido].compact_blank.join(" ")
  end

  private

  def generate_codigo
    last_number = self.class
      .where("codigo LIKE 'CEC-%'")
      .pluck(:codigo)
      .map { |c| c.sub("CEC-", "").to_i }
      .max || 0
    self.codigo = "CEC-#{(last_number + 1).to_s.rjust(3, '0')}"
  end
end
