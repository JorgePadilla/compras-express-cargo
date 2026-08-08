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
    tokens = Cliente.fragmentos_de(term)
    next all if tokens.empty?

    tokens.reduce(all) { |rel, token| rel.where(Cliente.condicion_fragmento(token)) }
  }

  # PR-10.f: la búsqueda que usan los autocompletes cuando el operario tiene
  # una etiqueta rota en la mano.
  #
  # Yusef: "a veces llegan las etiquetas rotas, solo dicen 234 y después dice
  # Pérez Hernández, entonces uno tiene que andar ahí unificando".
  #
  # `buscar` exige que TODAS las palabras matcheen, y con una etiqueta rota eso
  # es justo lo que falla: basta que un fragmento esté mal leído o pertenezca a
  # otro campo para que devuelva cero — peor que devolver algo aproximado.
  #
  # Primero intenta la estricta (idéntico a hoy en el caso normal, una sola
  # query). Solo si esa da cero cae a buscar por fragmentos sueltos.
  scope :buscar_flexible, ->(term) {
    estricta = buscar(term)
    # Con una sola palabra la estricta y la de fragmentos son equivalentes.
    next estricta.then { |r| Cliente.priorizar_codigo(r, term) } if Cliente.fragmentos_de(term).size <= 1
    next Cliente.priorizar_codigo(estricta, term) if estricta.exists?

    Cliente.priorizar_codigo(buscar_por_fragmentos(term), term)
  }

  # PR-C6.14b: pone primero al que el operario está buscando de verdad.
  #
  # Yusef, 2026-08-08, sobre cómo trabajan hoy: los códigos son `C00002867` y
  # "el sistema lee de derecha a izquierda... solo le ponían el dos, ponele que
  # el mío es el seis, solo poníamos el seis o el dos y ya con eso cae".
  #
  # **Encontrar ya funcionaba** — `codigo ILIKE '%2867%'` matchea el sufijo, y
  # los ceros a la izquierda ya se ignoran. Lo que faltaba era el **orden**:
  # con códigos de 5 dígitos, teclear `6` trae decenas y el que uno quiere
  # queda enterrado. Esa era la pregunta abierta del Excel.
  #
  # El desempate no inventa política, solo hace confiable lo que él describió:
  #
  #   1. el código que **es** ese número (ignorando ceros): `6` → `C00006`
  #   2. el que **termina** en ese número: `2867` → `C00002867`
  #   3. el resto
  def self.priorizar_codigo(relacion, term)
    digitos = term.to_s.gsub(/\D/, "").sub(/\A0+/, "").presence
    return relacion if digitos.nil?

    solo_digitos = "ltrim(regexp_replace(clientes.codigo, '\\D', '', 'g'), '0')"
    relacion.order(Arel.sql(sanitize_sql_array([ <<~SQL, digitos, digitos ])))
      CASE
        WHEN #{solo_digitos} = ?              THEN 0
        WHEN #{solo_digitos} LIKE '%%' || ?   THEN 1
        ELSE 2
      END
    SQL
  end

  # Trae los que matcheen AL MENOS UN fragmento, ordenados por cuántos
  # matchean. Con "234 Pérez Hernández", el cliente C234 Juan Pérez matchea 2
  # de 3 y queda arriba de los que solo matchean el apellido.
  scope :buscar_por_fragmentos, ->(term) {
    tokens = Cliente.fragmentos_de(term)
    next all if tokens.empty?

    condiciones = tokens.map { |t| Cliente.condicion_fragmento(t) }
    puntaje = condiciones.map { |c| "(CASE WHEN #{c} THEN 1 ELSE 0 END)" }.join(" + ")

    where(condiciones.join(" OR "))
      .order(Arel.sql("(#{puntaje}) DESC"), :codigo)
  }

  def self.fragmentos_de(term)
    term.to_s.strip.split(/\s+/).reject(&:blank?)
  end

  # Condición SQL para un fragmento suelto. Devuelve un string ya sanitizado,
  # apto para concatenarse con OR o envolverse en un CASE.
  def self.condicion_fragmento(token)
    like = "%#{sanitize_sql_like(token)}%"

    condiciones = [
      sanitize_sql_array([ "#{sin_acentos('clientes.codigo')} ILIKE #{sin_acentos('?')}", like ]),
      sanitize_sql_array([ "#{sin_acentos(NOMBRE_COMPLETO_SQL)} ILIKE #{sin_acentos('?')}", like ]),
      sanitize_sql_array([ "clientes.email ILIKE ?", like ])
    ]

    # Los ceros a la izquierda se ignoran a ambos lados: C002 == C2 == 2.
    normalizado = token.gsub(/\D/, "").sub(/\A0+/, "").presence
    if normalizado
      condiciones << sanitize_sql_array(
        [ "ltrim(regexp_replace(clientes.codigo, '\\D', '', 'g'), '0') = ?", normalizado ]
      )
    end

    "(#{condiciones.join(' OR ')})"
  end

  NOMBRE_COMPLETO_SQL = "(clientes.nombre || ' ' || COALESCE(clientes.apellido, ''))".freeze

  # PR-10.f: en Postgres `ILIKE` NO ignora acentos — 'Perez' ILIKE '%Pérez%' es
  # false. La base tiene los nombres sin tilde y el operario los teclea con
  # tilde (o al revés), así que sin esto la búsqueda falla en el caso más común.
  #
  # `translate` en vez de la extensión `unaccent` a propósito: es SQL puro, no
  # depende de que el entorno permita instalar extensiones, y se comporta igual
  # en local que en Render. Una búsqueda que difiere entre entornos es peor que
  # una limitada.
  def self.sin_acentos(expresion)
    "translate(#{expresion}, 'áéíóúüñÁÉÍÓÚÜÑ', 'aeiouunAEIOUN')"
  end

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
