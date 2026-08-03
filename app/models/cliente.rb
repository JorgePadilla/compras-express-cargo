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
  has_many :ventas, dependent: :restrict_with_error
  has_many :pagos, dependent: :restrict_with_error
  has_many :recibos, dependent: :restrict_with_error
  has_many :notas_debito,  dependent: :restrict_with_error
  has_many :notas_credito, dependent: :restrict_with_error
  has_many :cotizaciones, dependent: :restrict_with_error
  has_many :financiamientos, dependent: :restrict_with_error
  has_many :entregas, dependent: :restrict_with_error
  # PR-9.a: tareas que cualquier área le deja al cliente. Se destruyen con
  # el cliente porque no tienen valor fuera de su contexto (a diferencia de
  # paquetes o ventas, que son historia contable).
  has_many :tareas, dependent: :destroy

  validates :codigo, presence: true, uniqueness: { case_sensitive: false }
  validates :nombre, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true,
                   uniqueness: { case_sensitive: false, message: "ya esta registrado" }, if: -> { email.present? }
  validates :tema, inclusion: { in: %w[light dark], allow_nil: true }

  scope :activos, -> { where(activo: true) }
  # PR-10.c: búsqueda combinada de código y nombre. Antes hacía un `OR` sobre
  # columnas sueltas con el término completo, así que fallaba en los dos casos
  # que más usa el operario:
  #
  #   "Juan Perez"  → 0 resultados (ninguna columna sola contiene esa cadena)
  #   "C002"        → 0 resultados (el código real es C2)
  #
  # Yusef: "cuando hago búsquedas por código, quitar los ceros" y "a veces
  # llegan las etiquetas rotas: solo dicen 234 y después dice Pérez Hernández".
  #
  # Cada palabra del término tiene que matchear algo (AND entre palabras, OR
  # entre campos), así "2 María" encuentra a María con código C2.
  scope :buscar, ->(term) {
    tokens = term.to_s.strip.split(/\s+/).reject(&:blank?)
    next all if tokens.empty?

    tokens.reduce(all) do |rel, token|
      condiciones = [
        "clientes.codigo ILIKE :like",
        "(clientes.nombre || ' ' || COALESCE(clientes.apellido, '')) ILIKE :like",
        "clientes.email ILIKE :like"
      ]
      valores = { like: "%#{sanitize_sql_like(token)}%" }

      # Los ceros a la izquierda se ignoran a ambos lados: C002 == C2 == 2.
      normalizado = token.gsub(/\D/, "").sub(/\A0+/, "").presence
      if normalizado
        condiciones << "ltrim(regexp_replace(clientes.codigo, '\\D', '', 'g'), '0') = :codigo"
        valores[:codigo] = normalizado
      end

      rel.where(condiciones.join(" OR "), valores)
    end
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
