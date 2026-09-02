class User < ApplicationRecord
  has_secure_password

  # PR-13.c: el PIN de 4 dígitos con el que un supervisor autoriza un cambio de
  # precio en la pre-factura. Aparte de la contraseña a propósito: el supervisor
  # NO inicia sesión — el cajero sigue logueado y el supervisor solo teclea
  # cuatro dígitos parado en el mostrador.
  #
  # `validations: false` porque la mayoría de los usuarios no lleva PIN; las
  # reglas propias van abajo.
  has_secure_password :pin, validations: false

  # `pin_digest` va al skip junto con `password_digest`: es un hash, pero no
  # aporta nada al audit log y reduce la superficie ante una brecha.
  has_paper_trail skip: %i[password_digest pin_digest]
  has_many :sessions, dependent: :destroy
  # `RP-58` paso 2a · Los roles **además** del principal. Ver `RolDeUsuario`.
  has_many :roles_adicionales, class_name: "RolDeUsuario", dependent: :destroy
  accepts_nested_attributes_for :roles_adicionales, allow_destroy: true
  # Seguimiento de C18-02: la sucursal donde trabaja. Yusef: *"ahí vamos a
  # amarrar al usuario de dónde es"*. Opcional; si recibe carga, /etiquetar y
  # /entrega_personal la preseleccionan (`Sucursal.recepcion_por_defecto_para`).
  belongs_to :sucursal, optional: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Enums (string-backed for readable DB values)
  enum :rol, {
    admin: "admin",
    supervisor_miami: "supervisor_miami",
    digitador_miami: "digitador_miami",
    supervisor_caja: "supervisor_caja",
    supervisor_prefactura: "supervisor_prefactura",
    cajero: "cajero",
    sac: "sac",
    # PR-13.c: `sac` es el agente de servicio al cliente; este es su
    # supervisor, que Yusef cuenta también como jefe y por eso autoriza
    # cambios de precio en la pre-factura.
    supervisor_sac: "supervisor_sac",
    entrega_despacho: "entrega_despacho"
  }

  enum :ubicacion, {
    miami: "miami",
    honduras: "honduras"
  }

  # Validations
  validates :nombre, presence: true
  validates :email_address, presence: true, uniqueness: true
  validates :rol, presence: true
  validates :tema, inclusion: { in: %w[light dark], allow_nil: true }
  validates :iniciales, length: { maximum: 8 }, allow_blank: true
  validates :sidebar_position, inclusion: { in: %w[left right] }
  # PR-9.c: volumen de los tonos de escaneo, 0-100.
  validates :sonido_volumen, numericality: {
    only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100
  }
  # RP-20: cuál de las tres opciones del sonido de error. La lista sale de
  # `SonidosDeError`, que es la misma que toca el navegador y la misma que se
  # renderea a `.wav` — escribirla acá a mano sería un cuarto lugar donde
  # desincronizarse.
  # El lambda difiere la lectura: escrita como constante, `User` obligaría a
  # cargar `SonidosDeError` al arrancar y crearía un orden de carga que hoy no
  # hace falta.
  validates :sonido_error_variante, inclusion: { in: ->(_user) { SonidosDeError::IDS } }

  validates :pin, format: { with: /\A\d{4}\z/, message: "deben ser exactamente 4 digitos" },
                  confirmation: true, if: -> { pin.present? }

  # PR-13.c: quiénes pueden autorizar un cambio en una línea de pre-factura.
  # Yusef: "ahí es donde entra un jefe, un supervisor". Los cuatro que nombró.
  #
  # Ojo: autorizar NO es un permiso de pantalla y por eso no pasa por
  # `can_access?`. El supervisor nunca entra al sistema para esto — el cajero
  # está logueado y el supervisor solo pone su PIN.
  # `RP-58` paso 2a · **Todos** los roles de la persona: el principal más los
  # adicionales. Es la única lista que la autorización tiene derecho a mirar.
  #
  # Yusef pidió poder decir que alguien es *"Sub-Jefa de área de Caja y SAC"* sin
  # inventar un rol nuevo por cada combinación. Los roles **suman**: quien es
  # Caja y SAC entra a lo de Caja y a lo de SAC.
  #
  # Y ahí está la contracara, que conviene decirla en voz alta: **quitarle algo a
  # una persona con dos roles es quitárselo a los dos, o quitarle un rol**. La
  # pantalla de permisos sigue moviendo *roles*, no personas.
  def roles
    ([ rol ] + roles_adicionales.map(&:rol)).compact.uniq
  end

  # ¿Alguno de sus roles está en la lista? Es la forma que reemplaza a
  # `user.rol.in?(LISTA)` en **todo** chequeo de autorización: con dos roles, la
  # versión vieja miraba solo el principal y le negaba en silencio lo que el
  # segundo rol le daba. Hay un lint que traba que vuelva
  # (`test/lint/permisos_en_una_sola_fuente_test.rb`).
  def tiene_rol?(*lista)
    (roles & lista.flatten.map(&:to_s)).any?
  end

  # El área de **servicio al cliente**: el agente y su jefe.
  #
  # Estaba escrita a mano en `PermisosDelSistema` y **faltaba** en las tres
  # listas de tareas — por eso el jefe de SAC no veía la cola de SAC (`RP-45`).
  # Sale acá por lo mismo que `ROLES_DE_HONDURAS` y `ROLES_OPERATIVOS`: dos
  # copias de una lista de roles se desincronizan sin que nadie lo vea, y ésta
  # se desincronizó.
  ROLES_DE_SAC = %w[sac supervisor_sac].freeze

  ROLES_AUTORIZANTES = %w[admin supervisor_prefactura supervisor_caja supervisor_sac].freeze

  # `RP-58` paso 2a · Mira los roles adicionales también, y tiene que hacerlo en
  # SQL: es la lista que llena el dropdown de «¿quién autoriza?» en la
  # pre-factura. Con el `where(rol:)` a secas, alguien que autoriza por su
  # segundo rol no aparecía ahí — y `puede_autorizar?` sí lo dejaba pasar. Dos
  # respuestas distintas a la misma pregunta.
  scope :autorizantes, -> {
    activos.where.not(pin_digest: nil).where(
      "users.rol IN (:roles) OR users.id IN " \
      "(SELECT user_id FROM roles_de_usuario WHERE rol IN (:roles))",
      roles: ROLES_AUTORIZANTES
    )
  }

  def puede_autorizar?
    activo? && pin_digest.present? && tiene_rol?(ROLES_AUTORIZANTES)
  end

  # Puede tener PIN, aunque todavía no se lo hayan asignado.
  def rol_autorizante?
    tiene_rol?(ROLES_AUTORIZANTES)
  end

  # Todavía tiene el que le puso el admin. No bloquea nada —trabar el mostrador
  # por esto sería peor que el riesgo— pero se le avisa, porque mientras no lo
  # cambie el admin conoce el PIN con el que él autoriza, y el registro de
  # "quién autorizó" deja de probar nada.
  def pin_sin_cambiar?
    pin_digest.present? && pin_cambiado_at.nil?
  end

  # Scopes
  scope :activos, -> { where(activo: true) }
  scope :por_rol, ->(rol) { where(rol: rol) }
  scope :en_ubicacion, ->(ubicacion) { where(ubicacion: ubicacion) }
  scope :buscar, ->(term) {
    where("nombre ILIKE :q OR email_address ILIKE :q", q: "%#{sanitize_sql_like(term)}%")
  }

  ROL_DESCRIPTIONS = {
    "admin" => { label: "Administrador", descripcion: "Acceso total al sistema. Gestiona usuarios, configuraciones y todos los modulos." },
    "supervisor_miami" => { label: "Supervisor Miami", descripcion: "Supervisa recepcion, pre-alertas, re-empaque y digitadores en Miami." },
    "digitador_miami" => { label: "Digitador Miami", descripcion: "Etiqueta paquetes: escanea tracking, ingresa datos, imprime etiquetas en Miami." },
    "supervisor_caja" => { label: "Supervisor Caja", descripcion: "Supervisa pagos, cajeros, ventas y notas de debito/credito en Honduras." },
    "supervisor_prefactura" => { label: "Supervisor Pre-Factura", descripcion: "Supervisa generacion de pre-facturas y notas de debito." },
    "cajero" => { label: "Cajero", descripcion: "Procesa pagos de clientes, ventas y recibos en Honduras." },
    "sac" => { label: "Servicio al Cliente (SAC)", descripcion: "Atencion al cliente, consultas, reclamos y marketing." },
    "supervisor_sac" => { label: "Supervisor de Servicio al Cliente", descripcion: "Supervisa al equipo de SAC y autoriza cambios de precio en pre-factura." },
    "entrega_despacho" => { label: "Entrega y Despacho", descripcion: "Gestiona entregas finales de paquetes al cliente en Honduras." }
  }.freeze

  # `RP-58` paso 2b · **El único lugar donde se resuelve cómo se lee un rol.**
  #
  # La cadena es: lo que alguien renombró desde `/roles` → lo que trae el código
  # → el código del rol humanizado. Todo lo que muestre un rol pasa por acá; si
  # algo lo esquivara, renombrar dejaría la mitad de las pantallas diciendo el
  # nombre viejo — que es la forma en que este repo se lastima.
  #
  # La bitácora sale gratis: `paper_trail` guarda **códigos**, así que una
  # versión vieja de un rol renombrado se lee con el nombre de hoy, no con uno
  # que ya nadie reconoce.
  def self.titulo_de_rol(rol)
    codigo = rol.to_s
    TituloDeRol.mapa.dig(codigo, :label).presence ||
      ROL_DESCRIPTIONS.dig(codigo, :label).presence ||
      codigo.presence&.humanize
  end

  def self.descripcion_de_rol(rol)
    codigo = rol.to_s
    TituloDeRol.mapa.dig(codigo, :descripcion).presence ||
      ROL_DESCRIPTIONS.dig(codigo, :descripcion)
  end

  # Lo que trae el **código**, sin mirar lo renombrado. Lo usa `/roles` para
  # ofrecer «volver al del sistema» y para no guardar una fila que diga lo mismo.
  def self.titulo_del_sistema(rol)
    ROL_DESCRIPTIONS.dig(rol.to_s, :label) || rol.to_s.humanize
  end

  def self.descripcion_del_sistema(rol)
    ROL_DESCRIPTIONS.dig(rol.to_s, :descripcion)
  end

  def self.rol_options_for_select
    # El **value sigue siendo el código**: renombrar cambia lo que se lee, nunca
    # lo que el formulario manda.
    rols.keys.map { |key| [ "#{titulo_de_rol(key)} — #{descripcion_de_rol(key)}", key ] }
  end

  def rol_label
    User.titulo_de_rol(rol)
  end

  # `RP-58` paso 2a · Cómo se lee el puesto completo de alguien con dos roles:
  # «Supervisor Caja + SAC». Lo usan las pantallas que muestran el puesto.
  def roles_label
    roles.map { |r| User.titulo_de_rol(r) }.join(" + ")
  end

  # Los adicionales que se pueden elegir en el formulario: todos menos `admin`
  # —que va en el principal, ver `RolDeUsuario`— y menos el principal mismo.
  def roles_adicionales_elegibles
    ROL_DESCRIPTIONS.keys - [ "admin", rol ]
  end

  def roles_adicionales_lista
    roles_adicionales.map(&:rol)
  end

  # Reconcilia contra lo que vino del formulario: agrega los que faltan y borra
  # los que se destildaron. Se guarda al salvar el usuario, no antes, para que
  # un formulario rechazado no deje roles a medio aplicar.
  def roles_adicionales_lista=(valores)
    @roles_adicionales_lista = Array(valores).compact_blank.map(&:to_s).uniq
  end

  after_save :aplicar_roles_adicionales, if: -> { @roles_adicionales_lista }

  def nombre_completo
    nombre
  end

  # PR-D1.b: iniciales para mostrar en bitácora, WR, y cualquier campo
  # tipo "(YS)" en la UI. Si admin no asignó iniciales custom, computa
  # automáticamente desde el nombre como fallback razonable. La preferencia
  # es la columna explícita (Yusef pidió alias custom porque hay nombres
  # repetidos como "Juan").
  # RP-59 · **Este es el único lugar donde se calculan las iniciales.** El
  # Warehouse Receipt tenía su propia copia (`wr_user_initials`) que ignoraba la
  # columna y devolvía otro formato —`D.M.` contra `DM`—, así que el mismo papel
  # podía mostrar a la misma persona de dos maneras. Ahora el helper delega acá.
  #
  # La escalera de fallbacks, en orden: la columna que llena el admin, el
  # nombre, y el usuario del correo. El último venía del helper del WR y se
  # conserva: `nombre` es `NOT NULL DEFAULT ''`, así que puede estar vacío, y
  # ahí «—» esconde a alguien que sí se puede identificar.
  def iniciales_display
    return iniciales.upcase if iniciales.present?

    fuente = nombre.to_s.strip.presence || email_address.to_s.split("@").first.to_s
    parts = fuente.split(/[\s._-]+/).reject(&:blank?).first(2)
    return "—" if parts.empty?
    parts.map { |p| p[0].to_s.upcase }.join
  end

  # PR-9.a: "las notas se ordenan por la jerarquía de la empresa" (Yusef,
  # 2026-08-01) → orden por departamento: Miami → Caja → Pre-Factura → SAC
  # → Entrega. Pre-Factura y Entrega no tienen columna propia: ambas leen
  # `notas_honduras`, así que el orden efectivo colapsa a estos cuatro.
  NOTAS_DEPARTAMENTO_ORDEN = %i[notas_miami notas_caja notas_honduras notas_sac].freeze

  # PR-D2.b, ahora como tabla y no como `case`: con varios roles hay que poder
  # recorrerla rol por rol y unir, que un `case` sobre una sola variable no deja.
  NOTAS_POR_ROL = {
    "admin"                 => [ %i[notas_miami Miami], %i[notas_honduras Honduras],
                                 %i[notas_caja Caja], %i[notas_sac SAC] ],
    "supervisor_miami"      => [ %i[notas_miami Miami] ],
    "digitador_miami"       => [ %i[notas_miami Miami] ],
    "supervisor_caja"       => [ %i[notas_caja Caja], %i[notas_honduras Honduras] ],
    "cajero"                => [ %i[notas_caja Caja], %i[notas_honduras Honduras] ],
    "supervisor_prefactura" => [ %i[notas_honduras Honduras] ],
    "sac"                   => [ %i[notas_sac SAC], %i[notas_honduras Honduras] ],
    "supervisor_sac"        => [ %i[notas_sac SAC], %i[notas_honduras Honduras] ],
    "entrega_despacho"      => [ %i[notas_honduras Honduras] ]
  }.freeze

  # PR-D2.b: campos de `Cliente` con notas permanentes que el usuario
  # puede ver según su rol. Admin ve todas; cada rol operativo ve sólo
  # las notas pensadas para su área. Devuelve una lista ordenada para
  # renderizar el modal "Notas del cliente" en el detalle del paquete.
  def aplicar_roles_adicionales
    deseados = @roles_adicionales_lista - [ rol ]
    @roles_adicionales_lista = nil

    roles_adicionales.where.not(rol: deseados).destroy_all
    (deseados - roles_adicionales.reload.map(&:rol)).each do |r|
      roles_adicionales.create!(rol: r)
    end
  end

  def notas_permanentes_visibles
    # `RP-58` paso 2a · La **unión** de lo que ve cada uno de sus roles. Espeja
    # a `Tarea::DEPARTAMENTOS_POR_ROL`, que se resuelve igual: notas y tareas
    # se filtran con el mismo criterio a propósito, y si uno sumara roles y el
    # otro no, la incoherencia sería justo la que este método vino a evitar.
    roles
      .flat_map { |r| NOTAS_POR_ROL.fetch(r, []) }
      .uniq
      .sort_by { |campo, _| NOTAS_DEPARTAMENTO_ORDEN.index(campo) || NOTAS_DEPARTAMENTO_ORDEN.size }
      .map { |campo, etiqueta| { campo: campo, etiqueta: etiqueta } }
  end
end
