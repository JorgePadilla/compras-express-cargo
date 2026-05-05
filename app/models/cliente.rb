class Cliente < ApplicationRecord
  # PR-D1.a: audit log. Excluye `password_digest` (BCrypt hash) por
  # seguridad — aunque es hash y no plaintext, no aporta valor al
  # log y reduce la superficie ante una brecha del audit_log.
  has_paper_trail skip: %i[password_digest]

  # validations: false because admins create clients without passwords;
  # only clients who opt into portal access get a password set later.
  has_secure_password validations: false
  validates :password, length: { minimum: 8 }, confirmation: true, if: -> { password.present? }

  belongs_to :categoria_precio, optional: true
  has_many :paquetes, dependent: :restrict_with_error
  has_many :cliente_sessions, dependent: :destroy
  has_many :pre_alertas, dependent: :restrict_with_error
  has_many :pre_facturas, dependent: :restrict_with_error
  has_many :ventas, class_name: "Factura", dependent: :restrict_with_error
  has_many :pagos, dependent: :restrict_with_error
  has_many :recibos, dependent: :restrict_with_error
  has_many :notas_debito,  dependent: :restrict_with_error
  has_many :notas_credito, dependent: :restrict_with_error
  has_many :cotizaciones, dependent: :restrict_with_error
  has_many :financiamientos, dependent: :restrict_with_error
  has_many :entregas, dependent: :restrict_with_error

  validates :codigo, presence: true, uniqueness: { case_sensitive: false }
  validates :nombre, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true,
                   uniqueness: { case_sensitive: false, message: "ya esta registrado" }, if: -> { email.present? }
  validates :tema, inclusion: { in: %w[light dark], allow_nil: true }

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
      .where("codigo ~ '^C[0-9]+$'")
      .pluck(:codigo)
      .map { |c| c.sub("C", "").to_i }
      .max || 0
    self.codigo = "C#{last_number + 1}"
  end
end
