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
  # PR-C6.37: donde el cliente retira. Yusef: "la ciudad donde es la persona no
  # es el mismo lugar donde se le entrega — la idea es ponerle donde el hombre
  # va a querer su retiro". De aca lo hereda el paquete al etiquetarlo.
  belongs_to :sucursal_retiro, class_name: "Sucursal", optional: true
  has_many :paquetes, dependent: :restrict_with_error
  has_many :cliente_sessions, dependent: :destroy

  # PR-C6.41 · RP-04b: en qué servicios se le cobra SOLO el volumétrico.
  # La fila es el flag — ver `ClienteCobroVolumetrico`. `tipo_envio_solo_volumetrico_ids`
  # (que Rails deriva de este `has_many :through`) es lo que cablea el form.
  has_many :cliente_cobro_volumetricos, dependent: :destroy
  has_many :tipo_envio_solo_volumetricos,
           through: :cliente_cobro_volumetricos, source: :tipo_envio
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
  # Los correos a los que además hay que avisarle. El de **acceso** es `email`.
  has_many :cliente_correos, dependent: :destroy
  accepts_nested_attributes_for :cliente_correos, allow_destroy: true,
                                reject_if: ->(a) { a[:correo].blank? }

  validates :codigo, presence: true, uniqueness: { case_sensitive: false }
  validates :nombre, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true,
                   uniqueness: { case_sensitive: false, message: "ya esta registrado" }, if: -> { email.present? }
  validates :tema, inclusion: { in: %w[light dark], allow_nil: true }

  # ── El nombre completo lleva por lo menos tres palabras ─────────────────
  #
  # Yusef, 2026-08-19: *"tiene que poner mínimo **tres ítems**… por ejemplo yo me
  # llamo Alejandro Federico, tres nombres y mis dos apellidos. Entonces por lo
  # menos tenés que tener Jorge y dos apellidos"*. Y el porqué: *"imaginate
  # cuántos Jorge Padilla hay"*.
  #
  # En Honduras el nombre es el desempate cuando el casillero se lee mal — y las
  # etiquetas llegan rotas: *"a veces solo dicen 234 y después dice Pérez
  # Hernández"*.
  #
  # **Es una regla de la pantalla, no del modelo entero.** Hay 9.000 clientes
  # importados del sistema viejo y muchos vienen con dos palabras; una validación
  # a secas los volvería imposibles de guardar y trabaría la migración que Jorge
  # tiene pendiente —*"lo que más me preocupa es mover los clientes"*—.
  #
  # Corre solo cuando alguien está **tecleando** el nombre en `/clientes`, que es
  # donde Yusef la pidió. El importador, los seeds y las pruebas que solo
  # necesitan un cliente cualquiera no se enteran.
  attr_accessor :exigir_nombre_completo

  # Y además: **solo si el nombre de verdad cambió**. Guardar la ficha de un
  # cliente viejo reenviando su mismo nombre —que es lo que hace el formulario de
  # precios especiales— no puede trabarse por dos palabras que nadie tocó.
  validate :nombre_completo_lleva_tres_palabras,
           if: -> { exigir_nombre_completo && (new_record? || nombre_changed? || apellido_changed?) }

  scope :activos, -> { where(activo: true) }
  # Los que pueden entrar al portal. `activo` es "es cliente nuestro";
  # `acceso_habilitado` es "puede entrar". Son dos cosas distintas: se le corta
  # el acceso a alguien que sigue siendo cliente.
  scope :con_acceso, -> { activos.where(acceso_habilitado: true) }
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

  # Lo que Miami tiene que leer para saber en que bolsa va la caja. Cae a
  # `ciudad` mientras queden clientes sin sucursal asignada — es lo que la
  # etiqueta ya venia imprimiendo, asi que no empeora nada; solo deja de ser lo
  # unico que hay.
  def sucursal_retiro_nombre
    sucursal_retiro&.nombre.presence || ciudad.presence
  end

  # ¿La carga de este cliente va a donde va casi toda?
  #
  # Yusef, 2026-08-19: *"esa de San Pedro Sula hay que eliminarlo, porque es el
  # default… el cerebro trabaja en default; cuando querés que haga una cosa
  # diferente, tenés que ponerle la nota que es diferente"*. El 80% de la carga
  # se queda en San Pedro, y un aviso que sale siempre deja de leerse — y con él
  # el del día que dice Tegucigalpa, que era el único que importaba.
  #
  # Un cliente **sin** sucursal asignada no cuenta como default: de ese no se
  # sabe a dónde va, y ahí el aviso sirve.
  def retira_en_la_de_por_defecto?
    sucursal_retiro.present? && sucursal_retiro.retiro_por_defecto?
  end

  # El cliente entra con su **código de casillero o con su correo**.
  #
  # Yusef, 2026-08-19, dos veces: *"es que mi correo está lleno"*, *"es que yo no
  # tengo correo"*. En Honduras el correo no es el identificador que la gente
  # recuerda; el número de casillero sí, porque lo usan todos los días.
  #
  # Jorge argumentó que hoy la autenticación es por correo y es lo que funciona,
  # y quedaron en las dos: el correo sigue sirviendo para entrar, para notificar
  # y para recuperar la clave.
  #
  # `codigo` tiene índice único en la base, así que entrar por ahí es sólido.
  # `email` **no** —la unicidad la pone solo el modelo, o sea que no alcanza a
  # los 9.000 importados—, y por eso el de correo va segundo: si hay repetidos,
  # el código es el camino que no miente.
  #
  # `con_acceso` y no `activos`: se le puede cortar el acceso a alguien que sigue
  # siendo cliente.
  def self.autenticar(identificador, password)
    valor = identificador.to_s.strip
    return nil if valor.blank?

    con_acceso.authenticate_by(codigo: valor, password: password) ||
      con_acceso.authenticate_by(email: valor.downcase, password: password)
  end

  # ¿Ya le pusieron clave? Sin esto, `acceso_habilitado` miente: la casilla puede
  # estar marcada y el cliente igual no entra, porque el admin lo creó desde
  # `/clientes` y ahí nunca hubo dónde ponerle una.
  #
  # Yusef, 2026-08-19, mostrando el caso: *"ella tiene dos correos, **yo no le
  # puedo crear una cuenta aquí**"*.
  def tiene_clave?
    password_digest.present?
  end

  # A quién le corresponde el link de "olvidé mi contraseña".
  #
  # Busca por las **mismas dos llaves** con las que se entra (`autenticar`): si
  # solo mirara el correo, el cliente que Yusef describe —*"es que yo no tengo
  # correo"*— quedaría afuera justo del camino que existe para él.
  #
  # Devuelve al cliente aunque no tenga clave puesta: recuperarla es también
  # **estrenarla**, y es la salida para el que el admin creó sin cuenta.
  def self.para_recuperar(identificador)
    valor = identificador.to_s.strip
    return nil if valor.blank?

    con_acceso.find_by(codigo: valor) || con_acceso.find_by(email: valor.downcase)
  end

  # Le pone (o le cambia) la clave. `clave_actualizada_at` es lo que deja la
  # huella: `has_paper_trail` saltea `password_digest`, así que sin esta columna
  # el cambio no aparecería en ninguna bitácora.
  def cambiar_clave(nueva, confirmacion)
    self.password = nueva
    self.password_confirmation = confirmacion
    self.clave_actualizada_at = Time.current
    save
  end

  PALABRAS_MINIMAS_DEL_NOMBRE = 3

  def nombre_completo_lleva_tres_palabras
    return if nombre_completo.to_s.split.size >= PALABRAS_MINIMAS_DEL_NOMBRE

    errors.add(:nombre, "va con nombre y dos apellidos (al menos #{PALABRAS_MINIMAS_DEL_NOMBRE} palabras)")
  end

  def nombre_completo
    [nombre, apellido].compact_blank.join(" ")
  end

  # PR-C6.41 · RP-04b: ¿a este cliente se le cobra SOLO el volumétrico en este
  # servicio? Es lo único que el motor de cobro necesita saber.
  #
  # Es **por servicio**, no por cliente: el mismo mayorista puede tener el trato
  # en CEM y pagar normal en CER. `tipo_envio` puede venir nil (`Paquete` lo
  # tiene `optional: true`) y ahí no aplica nada.
  def cobra_solo_volumetrico?(tipo_envio)
    id = tipo_envio.respond_to?(:id) ? tipo_envio&.id : tipo_envio
    return false if id.blank?

    tipo_envio_solo_volumetrico_ids.include?(id)
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
