class User < ApplicationRecord
  has_secure_password
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
      when "sac"
        [ %i[notas_sac SAC], %i[notas_honduras Honduras] ]
      when "entrega_despacho"
        [ %i[notas_honduras Honduras] ]
      else
        []
      end
    pares.map { |campo, etiqueta| { campo: campo, etiqueta: etiqueta } }
  end
end
