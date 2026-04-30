class Paquete < ApplicationRecord
  has_paper_trail  # PR-D1.a: audit log de cada cambio en el paquete

  belongs_to :cliente
  belongs_to :manifiesto, optional: true
  belongs_to :tipo_envio, optional: true
  belongs_to :user, optional: true
  belongs_to :pre_factura, optional: true
  belongs_to :venta, optional: true
  belongs_to :entrega, optional: true
  belongs_to :sucursal, optional: true
  belongs_to :sucursal_actual,      class_name: "Sucursal",      optional: true  # PR-D1.c: ubicación física actual
  belongs_to :sub_localidad_actual, class_name: "SubLocalidad",  optional: true  # PR-D1.c: bodega interna actual
  belongs_to :warehouse_receipt, optional: true  # PR-5c.5p2 — fuente rica del numero_recepcion (madre)
  has_many :pre_alerta_paquetes, dependent: :nullify
  has_many :nota_debito_items,  dependent: :nullify
  has_many :nota_credito_items, dependent: :nullify
  has_many :tareas, dependent: :destroy
  has_many :reempaques, dependent: :destroy

  enum :estado, {
    pre_alerta_estado:     "pre_alerta_estado",  # PR-D1.b: paquete creado desde pre-alerta antes de llegar a Miami
    recibido_miami:        "recibido_miami",
    empacado:              "empacado",
    enviado_honduras:      "enviado_honduras",
    en_aduana:             "en_aduana",
    consolidando_honduras: "consolidando_honduras",
    disponible_entrega:    "disponible_entrega",
    pre_facturado:         "pre_facturado",
    facturado:             "facturado",
    en_reparto:            "en_reparto",
    recoleta_en_proceso:   "recoleta_en_proceso",
    entregado:             "entregado",
    retenido:              "retenido",
    retornado:             "retornado",
    desechado:             "desechado",
    anulado:               "anulado"
  }

  # PR-D1.b: mapping estado → columna de fecha. El cambio a un estado
  # actualiza `fecha_<estado>` + `fecha_<estado>_by_user_id` (excepto
  # pre_alerta que NUNCA se sobrescribe — Yusef 2026-04-29).
  ESTADO_FECHA_MAP = {
    "pre_alerta_estado"  => :fecha_pre_alerta,
    "recibido_miami"     => :fecha_recibido_miami,
    "empacado"           => :fecha_empacado,
    "enviado_honduras"   => :fecha_enviado,
    "en_aduana"          => :fecha_aduana,
    "consolidando_honduras" => :fecha_consolidando,
    "disponible_entrega" => :fecha_disponible,
    "en_reparto"         => :fecha_en_reparto,
    "entregado"          => :fecha_entregado
  }.freeze

  # Fechas que NO se sobrescriben una vez seteadas (queda la primera).
  ESTADO_FECHA_INMUTABLE = %i[fecha_pre_alerta].freeze

  validates :tracking, presence: true
  validates :guia, presence: true, uniqueness: { case_sensitive: false }
  validates :estado, presence: true
  validates :peso, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :alto, :largo, :ancho, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :no_advance_with_open_tareas
  validate :sub_localidad_pertenece_a_sucursal_actual

  # PR-D1.c: tarifa fija pre-establecida $35 USD + ISV (Yusef 2026-04-29).
  # Editable por el cajero al crear/asignar la recolecta. No hay tabla de
  # tarifas por zona todavía porque siempre cambia.
  RECOLECTA_TARIFA_DEFAULT_USD = 35.0
  RECOLECTA_MONEDAS = %w[USD LPS].freeze

  # Orden del pipeline operativo; avances a un indice mayor requieren que
  # las tareas pendientes del paquete esten cerradas.
  ESTADOS_ORDEN = %w[recibido_miami empacado enviado_honduras en_aduana
                     disponible_entrega pre_facturado facturado en_reparto entregado].freeze

  scope :activos, -> { where.not(estado: %w[anulado entregado retornado desechado]) }
  scope :buscar, ->(term) {
    q = "%#{sanitize_sql_like(term)}%"
    left_joins(:cliente, :tipo_envio, :manifiesto).where(
      <<~SQL,
        paquetes.tracking ILIKE :q
        OR paquetes.tracking_secundario ILIKE :q
        OR paquetes.guia ILIKE :q
        OR paquetes.numero_recepcion ILIKE :q
        OR paquetes.descripcion ILIKE :q
        OR clientes.codigo ILIKE :q
        OR clientes.nombre ILIKE :q
        OR clientes.apellido ILIKE :q
        OR tipo_envios.codigo ILIKE :q
        OR tipo_envios.nombre ILIKE :q
        OR manifiestos.numero ILIKE :q
      SQL
      q: q
    )
  }
  scope :by_estado, ->(estado) { where(estado: estado) }
  scope :by_estados, ->(arr) { where(estado: Array(arr).compact_blank) }
  scope :by_tipo_envio, ->(tipo_envio_id) { where(tipo_envio_id: tipo_envio_id) }
  scope :by_tipos_envio, ->(arr) { where(tipo_envio_id: Array(arr).compact_blank) }
  scope :by_cliente, ->(cliente_id) { where(cliente_id: cliente_id) }
  scope :by_sucursal, ->(ids) { where(sucursal_id: Array(ids).compact_blank) }
  scope :recibidos_hoy, -> { where(fecha_recibido_miami: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :sin_manifiesto, -> { where(manifiesto_id: nil).where.not(estado: %w[anulado entregado retornado desechado]) }
  scope :facturables, -> { where(estado: "disponible_entrega", pre_factura_id: nil, venta_id: nil) }
  scope :entregables, -> { where(estado: "facturado", entrega_id: nil) }
  # Paquetes sin vincular a ninguna pre_alerta_paquete (sueltos en bodega)
  scope :sin_pre_alerta, -> {
    left_joins(:pre_alerta_paquetes).where(pre_alerta_paquetes: { id: nil })
  }

  before_validation :generate_guia, on: :create, if: -> { guia.blank? }
  before_validation :generate_numero_recepcion, on: :create, if: -> { numero_recepcion.blank? && sucursal_id.present? }
  before_validation :default_recolecta_monto, if: -> { recolecta_solicitada? && recolecta_monto.blank? }
  after_create :ensure_warehouse_receipt, if: -> { warehouse_receipt_id.nil? && numero_recepcion.present? && cliente_id.present? }
  before_save :set_fecha_recibido, if: -> { fecha_recibido_miami.blank? && new_record? }
  before_save :calculate_peso_volumetrico
  before_save :calculate_peso_cobrar
  before_save :track_fecha_disponible, if: :will_save_change_to_estado?
  before_save :track_estado_fecha_y_user, if: :will_save_change_to_estado?
  after_save :sync_pre_alerta_estados, if: :saved_change_to_estado?

  def estado_terminal?
    entregado? || anulado? || retornado? || desechado?
  end

  # ── Sub-etiquetas / split de tracking en N bultos ──
  # `numero_caja` (1..N) + `cantidad_paquetes` (total) reusados del módulo 36.
  # Un paquete dividido es un bulto físico identificado como "1/3", "2/3", etc.

  # True si el paquete pertenece a un tracking dividido en >1 bulto.
  def dividido?
    cantidad_paquetes.to_i > 1
  end

  # Devuelve "1/3" cuando el paquete está dividido; nil cuando no.
  # Se muestra en etiqueta impresa, detalle y badges del listado.
  def etiqueta_secuencia
    return nil unless dividido?
    return nil if numero_caja.to_i.zero?
    "#{numero_caja}/#{cantidad_paquetes}"
  end

  # Otros bultos del mismo tracking dividido (sin incluir self). Útiles
  # para mostrar "ver hermanos" en el detalle.
  def paquetes_hermanos
    return Paquete.none unless dividido? && tracking.present?
    Paquete.where(tracking: tracking).where.not(id: id)
  end

  # Crea N paquetes "hijos" en una sola transacción cuando el digitador
  # divide un tracking en varios bultos físicos (split de etiqueta).
  #
  # Reglas (Yusef, spec 2026-04-28):
  #   - El digitador llena los datos UNA vez, indica `total_cajas`.
  #   - El sistema replica esos datos en N paquetes:
  #       * todos comparten el mismo `tracking`,
  #       * todos comparten el mismo `numero_recepcion` (número MADRE / WR único),
  #       * `numero_caja` 1..N, `cantidad_paquetes` = N (para mostrar "1/N").
  #   - El número madre se solicita UNA sola vez al counter y se asigna a las N filas.
  #   - El unique index compuesto `(numero_recepcion, numero_caja)` garantiza que
  #     no se dupliquen cajas del mismo madre.
  #   - Si el save de cualquiera falla, la transacción hace rollback.
  #
  # Devuelve un array con los paquetes creados (en orden 1..N).
  def self.crear_split!(attrs:, total_cajas:)
    n = total_cajas.to_i
    raise ArgumentError, "total_cajas debe ser >= 2" if n < 2

    sucursal     = attrs[:sucursal]     || Sucursal.find_by(id: attrs[:sucursal_id])
    cliente      = attrs[:cliente]      || Cliente.find_by(id: attrs[:cliente_id])
    numero_madre = generate_numero_recepcion_madre(sucursal: sucursal, attrs: attrs)

    transaction do
      # PR-5c.5p2: crea el WR madre antes de los paquetes y los enlaza.
      wr = build_warehouse_receipt(
        receipt_number: numero_madre,
        cliente: cliente,
        sucursal: sucursal,
        attrs: attrs
      )
      wr&.save!

      (1..n).map do |i|
        Paquete.create!(attrs.merge(
          numero_caja: i,
          cantidad_paquetes: n,
          numero_recepcion: numero_madre,
          warehouse_receipt_id: wr&.id
        ))
      end
    end
  end

  # Construye un WarehouseReceipt para el split. Solo se crea cuando hay
  # cliente+receipt_number+sucursal — ausente en fixtures y tests legacy.
  # Retorna nil cuando faltan datos para no romper esos casos.
  def self.build_warehouse_receipt(receipt_number:, cliente:, sucursal:, attrs:)
    return nil if cliente.nil? || receipt_number.blank?

    fecha = attrs[:fecha_recibido_miami] || Time.zone.now
    issued_on = fecha.respond_to?(:to_date) ? fecha.to_date : Time.zone.today

    WarehouseReceipt.new(
      receipt_number: receipt_number,
      issued_on:      issued_on,
      consignee:      cliente,
      sucursal:       sucursal,
      user:           attrs[:user],
      status:         "received"
    )
  end

  # Genera el número madre que las N cajas del split compartirán. Usa el
  # mismo counter anual que un paquete single (1 sola llamada — incrementa
  # el contador 1 vez, no N).
  def self.generate_numero_recepcion_madre(sucursal:, attrs:)
    return nil if sucursal.nil?
    prefix = sucursal.codigo_recepcion_prefix
    return nil if prefix.blank?

    fecha = attrs[:fecha_recibido_miami] || Time.zone.now
    anio = fecha.respond_to?(:year) ? fecha.year : Time.zone.now.year
    next_number = NumeroRecepcionCounter.next_for!(sucursal: sucursal, anio: anio)

    format("%<prefix>s%<anio>07d%<num>06d", prefix: prefix, anio: anio, num: next_number)
  end

  # Calcula la próxima letra A-Z disponible para distinguir un tracking
  # físicamente duplicado (paquetes distintos que comparten el mismo
  # tracking impreso por reciclaje del courier).
  #
  # Reglas (Yusef, 2026-04-25):
  #   - 1° con tracking_base: el original (sin sufijo).
  #   - 2°: tracking_base + "A"
  #   - 3°: tracking_base + "B"
  #   - ...
  #   - 27°: no se permite — devuelve nil (intervención manual del supervisor).
  #
  # Devuelve la letra (String "A".."Z") a usar para el próximo paquete con
  # ese mismo `tracking_base`, o nil si ya se agotó el alfabeto.
  def self.next_duplicate_suffix(tracking_base)
    return nil if tracking_base.blank?

    base = tracking_base.to_s
    # Encuentra todos los suffixed existentes para este base. Solo letras
    # A-Z mayúsculas inmediatamente después del base, sin nada más detrás.
    used = where("tracking ~ ?", "^#{Regexp.escape(base)}[A-Z]$")
             .pluck(:tracking)
             .map { |t| t[base.length..] }
             .compact

    if used.empty?
      "A"
    else
      max_letter = used.max
      next_index = max_letter.ord - "A".ord + 1
      return nil if next_index >= 26
      ("A".ord + next_index).chr
    end
  end

  # True si el paquete esta vinculado a alguna pre-alerta consolidando.
  # Evita N+1: si pre_alerta_paquetes ya esta preloaded, usa la coleccion en
  # memoria (caso del listado admin con includes). Si no, hace 1 query.
  def consolidado?
    if pre_alerta_paquetes.loaded?
      pre_alerta_paquetes.any? { |pap| pap.pre_alerta&.consolidado? }
    else
      pre_alerta_paquetes.joins(:pre_alerta).exists?(pre_alertas: { consolidado: true })
    end
  end

  # True when at least one tarea vinculada sigue abierta (pendiente/en_proceso).
  # Los operadores no pueden avanzar el paquete a siguientes estados mientras
  # queden tareas sin realizar.
  def tareas_pendientes?
    tareas.abiertas.exists?
  end

  # Retry on guia collisions (old max+1 generator). numero_recepcion usa una
  # PostgreSQL sequence atomica por sucursal (`nextval`), por lo que nunca
  # debe colisionar para records nuevos — la migracion inicial hizo setval
  # al max existente, y nextval garantiza unicidad para inserts concurrentes.
  # Si hay una colision de numero_recepcion, es un problema de integridad
  # (data legacy insertada fuera de la sequence) y bubbleamos el error.
  def save(**args, &block)
    super
  rescue ActiveRecord::RecordNotUnique => e
    raise unless new_record? && e.message.include?("guia") && (@_guia_retries ||= 0) < 3
    @_guia_retries += 1
    self.guia = nil
    generate_guia
    retry
  end

  private

  def no_advance_with_open_tareas
    return if new_record? || !estado_changed?

    old_idx = ESTADOS_ORDEN.index(estado_was)
    new_idx = ESTADOS_ORDEN.index(estado)
    return unless old_idx && new_idx && new_idx > old_idx
    return unless tareas.abiertas.exists?

    errors.add(:estado, "no se puede avanzar: el paquete tiene tareas pendientes")
  end

  def sync_pre_alerta_estados
    pre_alerta_paquetes.includes(:pre_alerta).each do |pap|
      pap.pre_alerta&.actualizar_estado_from_paquetes!
    end
  end

  def generate_guia
    next_number = (self.class.where("guia LIKE 'PQ-%'").maximum(Arel.sql("CAST(SUBSTRING(guia FROM 4) AS INTEGER)")) || 0) + 1
    self.guia = "PQ-#{next_number.to_s.rjust(6, '0')}"
  end

  # Numero de recepcion formato anual:
  #
  #   <PREFIX><AÑO 7-DIGITOS><CONTADOR 6-DIGITOS>
  #
  # Ej: `RM0002026000042` = Recibido Miami, año 2026, paquete #42 del año.
  # El contador reinicia el 1 de enero. Atomico via NumeroRecepcionCounter
  # (lock FOR UPDATE sobre (sucursal_id, anio)).
  #
  # El unique index en paquetes.numero_recepcion es la salvaguarda final;
  # el retry en `save` cubre colisiones con data legacy que no pasó por
  # el counter.
  def generate_numero_recepcion
    return if sucursal.nil?
    prefix = sucursal.codigo_recepcion_prefix
    return if prefix.blank?

    anio = (fecha_recibido_miami&.year || Time.zone.now.year)
    next_number = NumeroRecepcionCounter.next_for!(sucursal: sucursal, anio: anio)

    self.numero_recepcion = format(
      "%<prefix>s%<anio>07d%<num>06d",
      prefix: prefix,
      anio:   anio,
      num:    next_number
    )
  end

  # Registra la primera vez que el paquete llega a disponible_entrega.
  # Una vez seteada, NO se borra si el estado avanza (pre_facturado,
  # facturado, entregado...) porque es un timestamp historico util para
  # reportes y listados. Tampoco se resetea si retrocede por correccion
  # administrativa: mantener el timestamp original evita perder trazabilidad.
  # Si en el futuro se necesita "fecha programada vs fecha real", se agrega
  # un segundo campo (ej. fecha_disponible_programada).
  def track_fecha_disponible
    return unless estado == "disponible_entrega"
    self.fecha_disponible ||= Time.current
  end

  # PR-D1.b: cuando cambia el estado, setea la fecha correspondiente +
  # quién la disparó. Las fechas en ESTADO_FECHA_INMUTABLE solo se setean
  # si están en blanco (no sobrescriben).
  def track_estado_fecha_y_user
    fecha_attr = ESTADO_FECHA_MAP[estado]
    return if fecha_attr.nil?

    user_attr = "#{fecha_attr}_by_user_id"

    if ESTADO_FECHA_INMUTABLE.include?(fecha_attr)
      # Solo setea si está en blanco. Conserva el primer valor.
      return if self[fecha_attr].present?
      self[fecha_attr] = Time.current
      self[user_attr] = Current.user&.id
    else
      self[fecha_attr] = Time.current
      self[user_attr] = Current.user&.id
    end
  end

  def set_fecha_recibido
    self.fecha_recibido_miami = Time.current
  end

  def calculate_peso_volumetrico
    if alto.present? && largo.present? && ancho.present?
      self.peso_volumetrico = (alto * largo * ancho / 166.0).round(2)
    end
  end

  def calculate_peso_cobrar
    if peso.present? || peso_volumetrico.present?
      self.peso_cobrar = [peso || 0, peso_volumetrico || 0].max
    end
  end

  # PR-D1.c: cuando se marca recolecta_solicitada y aún no hay monto,
  # auto-llena con la tarifa default de $35 USD. El cajero puede editarlo.
  def default_recolecta_monto
    self.recolecta_monto = RECOLECTA_TARIFA_DEFAULT_USD
    self.recolecta_moneda ||= "USD"
  end

  # PR-D1.c: si se asigna sub_localidad_actual, debe pertenecer a la
  # sucursal_actual (consistencia referencial — no se puede meter un
  # paquete en una bodega de Zerón si dijiste que está en Humuya).
  def sub_localidad_pertenece_a_sucursal_actual
    return if sub_localidad_actual.blank? || sucursal_actual.blank?
    return if sub_localidad_actual.sucursal_id == sucursal_actual_id
    errors.add(:sub_localidad_actual, "no pertenece a la sucursal actual")
  end

  # PR-5c.5p2: para paquetes creados fuera de `crear_split!` (flow normal de
  # /etiquetar single, fixtures, scripts), crea/encuentra un WR madre con
  # el mismo numero_recepcion. Las N cajas de un split (que comparten
  # numero_recepcion) terminan apuntando al mismo WR aunque cada una entre
  # por aquí — el find_or_create_by hace el match por receipt_number.
  def ensure_warehouse_receipt
    wr = WarehouseReceipt.find_or_initialize_by(receipt_number: numero_recepcion)
    if wr.new_record?
      wr.assign_attributes(
        issued_on: (fecha_recibido_miami&.to_date || created_at&.to_date || Time.zone.today),
        consignee: cliente,
        sucursal: sucursal,
        user: user,
        status: "received"
      )
      wr.save!
    end
    update_column(:warehouse_receipt_id, wr.id) if warehouse_receipt_id != wr.id
  end
end
