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

  validates :pin, format: { with: /\A\d{4}\z/, message: "deben ser exactamente 4 digitos" },
                  confirmation: true, if: -> { pin.present? }

  # PR-13.c: quiénes pueden autorizar un cambio en una línea de pre-factura.
  # Yusef: "ahí es donde entra un jefe, un supervisor". Los cuatro que nombró.
  #
  # Ojo: autorizar NO es un permiso de pantalla y por eso no pasa por
  # `can_access?`. El supervisor nunca entra al sistema para esto — el cajero
  # está logueado y el supervisor solo pone su PIN.
  ROLES_AUTORIZANTES = %w[admin supervisor_prefactura supervisor_caja supervisor_sac].freeze

  scope :autorizantes, -> { activos.where(rol: ROLES_AUTORIZANTES).where.not(pin_digest: nil) }

  def puede_autorizar?
    activo? && pin_digest.present? && rol.in?(ROLES_AUTORIZANTES)
  end

  # Puede tener PIN, aunque todavía no se lo hayan asignado.
  def rol_autorizante?
    rol.in?(ROLES_AUTORIZANTES)
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

  def self.rol_options_for_select
    ROL_DESCRIPTIONS.map { |key, info| ["#{info[:label]} — #{info[:descripcion]}", key] }
  end

  def rol_label
    ROL_DESCRIPTIONS.dig(rol, :label) || rol&.humanize
  end

  def nombre_completo
    nombre
  end

  # PR-D1.b: iniciales para mostrar en bitácora, WR, y cualquier campo
  # tipo "(YS)" en la UI. Si admin no asignó iniciales custom, computa
  # automáticamente desde el nombre como fallback razonable. La preferencia
  # es la columna explícita (Yusef pidió alias custom porque hay nombres
  # repetidos como "Juan").
  def iniciales_display
    return iniciales.upcase if iniciales.present?
    parts = nombre.to_s.split(/\s+/).reject(&:blank?).first(2)
    return "—" if parts.empty?
    parts.map { |p| p[0].to_s.upcase }.join
  end

  # PR-9.a: "las notas se ordenan por la jerarquía de la empresa" (Yusef,
  # 2026-08-01) → orden por departamento: Miami → Caja → Pre-Factura → SAC
  # → Entrega. Pre-Factura y Entrega no tienen columna propia: ambas leen
  # `notas_honduras`, así que el orden efectivo colapsa a estos cuatro.
  NOTAS_DEPARTAMENTO_ORDEN = %i[notas_miami notas_caja notas_honduras notas_sac].freeze

  # PR-D2.b: campos de `Cliente` con notas permanentes que el usuario
  # puede ver según su rol. Admin ve todas; cada rol operativo ve sólo
  # las notas pensadas para su área. Devuelve una lista ordenada para
  # renderizar el modal "Notas del cliente" en el detalle del paquete.
  def notas_permanentes_visibles
    pares =
      case rol
      when "admin"
        [ %i[notas_miami Miami], %i[notas_honduras Honduras],
          %i[notas_caja Caja], %i[notas_sac SAC] ]
      when "supervisor_miami", "digitador_miami"
        [ %i[notas_miami Miami] ]
      when "supervisor_caja", "cajero"
        [ %i[notas_caja Caja], %i[notas_honduras Honduras] ]
      when "supervisor_prefactura"
        [ %i[notas_honduras Honduras] ]
      when "sac", "supervisor_sac"
        [ %i[notas_sac SAC], %i[notas_honduras Honduras] ]
      when "entrega_despacho"
        [ %i[notas_honduras Honduras] ]
      else
        []
      end
    pares
      .sort_by { |campo, _| NOTAS_DEPARTAMENTO_ORDEN.index(campo) || NOTAS_DEPARTAMENTO_ORDEN.size }
      .map { |campo, etiqueta| { campo: campo, etiqueta: etiqueta } }
  end
end
