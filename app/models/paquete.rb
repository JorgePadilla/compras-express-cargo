class Paquete < ApplicationRecord
  has_paper_trail  # PR-D1.a: audit log de cada cambio en el paquete

  belongs_to :cliente
  belongs_to :manifiesto, optional: true
  belongs_to :tipo_envio, optional: true
  belongs_to :user, optional: true
  belongs_to :pre_factura, optional: true
  belongs_to :venta, optional: true
  belongs_to :entrega, optional: true
  belongs_to :tipo_envio_anterior,  class_name: "TipoEnvio",   optional: true  # PR-C6.8: de qué servicio venía al cambiarlo
  belongs_to :sucursal, optional: true                                           # dónde RETIRA el cliente
  belongs_to :sucursal_recepcion,   class_name: "Sucursal",      optional: true  # PR-C6.5: dónde se RECIBIÓ — manda el número de recepción
  belongs_to :sucursal_actual,      class_name: "Sucursal",      optional: true  # PR-D1.c: ubicación física actual
  belongs_to :sub_localidad_actual, class_name: "SubLocalidad",  optional: true  # PR-D1.c: bodega interna actual
  belongs_to :warehouse_receipt, optional: true  # PR-5c.5p2 — fuente rica del numero_recepcion (madre)
  belongs_to :proveedor, optional: true  # PR-D3.a: catálogo (Amazon, Walmart, drivers privados…)
  belongs_to :tercero, class_name: "Cliente", optional: true  # PR-D3.c: cliente final cuando CEC le maneja carga a otra empresa
  belongs_to :tarifa_recolecta, optional: true  # PR-D6.a: cuando el cajero elige una tarifa del catálogo, copiamos monto+moneda
  # PR-6 (Entrega Personal): cobro al recibir en Miami. Cuando esto está
  # marcado, NO se emite factura formal — solo se anota que ya pagó.
  belongs_to :prepagado_miami_sucursal, class_name: "Sucursal", optional: true
  belongs_to :prepagado_miami_by_user,  class_name: "User",     optional: true
  has_many :pre_alerta_paquetes, dependent: :nullify
  has_many :nota_debito_items,  dependent: :nullify
  has_many :nota_credito_items, dependent: :nullify
  has_many :tareas, dependent: :destroy
  has_many :reempaques, dependent: :destroy

  # PR-D2: multi-select de motivos cuando se retiene el paquete.
  has_many :paquete_motivos_retencion,
           class_name: "PaqueteMotivoRetencion",
           dependent: :destroy
  has_many :motivos_retencion,
           through: :paquete_motivos_retencion,
           source:  :motivo_retencion

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
  # Yusef pidió que fecha_pre_alerta sí se actualice al mover el paquete
  # a otra PA — la última transacción manda — así que ya no es inmutable.
  ESTADO_FECHA_INMUTABLE = %i[].freeze

  validates :tracking, presence: true
  # PR-10.d: `PreAlertaPaquete` ya validaba el formato y `Paquete` no, pese a
  # que la spec lo pide (docs/05). El tracking se imprime en la etiqueta y
  # alimenta el código de barras, así que se acota en el modelo.
  #
  # A propósito NO es tan estricta como la de `PreAlertaPaquete`: acá el valor
  # lo teclea el digitador con un tracking real de carrier, y una regex de más
  # lo dejaría sin poder guardar el paquete. Lo que sí se corta es el
  # whitespace y los caracteres de markup — que es lo único que importaba.
  TRACKING_FORMATO = /\A[A-Za-z0-9._\-\/]+\z/
  validates :tracking, format: {
    with: TRACKING_FORMATO,
    message: "no permite espacios ni símbolos (solo letras, números, . _ - /)"
  }, allow_blank: true
  validates :guia, presence: true, uniqueness: { case_sensitive: false }
  validates :estado, presence: true
  validates :peso, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :alto, :largo, :ancho, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :no_advance_with_open_tareas
  validate :sub_localidad_pertenece_a_sucursal_actual
  validate :retencion_requiere_motivo_o_notas, if: -> { estado == "retenido" }

  # PR-D1.c: tarifa fija pre-establecida $35 USD + ISV (Yusef 2026-04-29).
  # Editable por el cajero al crear/asignar la recolecta. No hay tabla de
  # tarifas por zona todavía porque siempre cambia.
  RECOLECTA_TARIFA_DEFAULT_USD = 35.0
  RECOLECTA_MONEDAS = %w[USD LPS].freeze

  # Orden del pipeline operativo; avances a un indice mayor requieren que
  # las tareas pendientes del paquete esten cerradas.
  ESTADOS_ORDEN = %w[recibido_miami empacado enviado_honduras en_aduana
                     disponible_entrega pre_facturado facturado en_reparto entregado].freeze

  # Estados excepcionales / fuera del pipeline lineal. Las transiciones
  # hacia o desde estos NO se consideran "retroceso" (son rutas
  # alternativas válidas como retención, anulación, consolidación).
  ESTADOS_EXCEPCIONALES = %w[pre_alerta_estado consolidando_honduras
                              recoleta_en_proceso retenido retornado
                              desechado anulado].freeze

  # PR-D7.d: al confirmar un retroceso, limpiar fechas + users de los
  # estados posteriores al nuevo. Yusef pidió "que el paquete quede
  # limpio en los estados que ya no aplican".
  RETROCESO_CLEANUP_FECHAS_POR_ESTADO = {
    "empacado"              => %i[fecha_empacado fecha_empacado_by_user_id],
    "enviado_honduras"      => %i[fecha_enviado fecha_enviado_by_user_id],
    "en_aduana"             => %i[fecha_aduana fecha_aduana_by_user_id],
    "consolidando_honduras" => %i[fecha_consolidando fecha_consolidando_by_user_id],
    "disponible_entrega"    => %i[fecha_disponible fecha_disponible_by_user_id
                                  fecha_posible_entrega fecha_posible_entrega_by_user_id],
    "en_reparto"            => %i[fecha_en_reparto fecha_en_reparto_by_user_id],
    "entregado"             => %i[fecha_entregado fecha_entregado_by_user_id]
  }.freeze

  # FK que se desliga si el estado nuevo es ANTERIOR al estado mínimo
  # donde la asociación se setea.
  RETROCESO_CLEANUP_FKS_DESDE_ESTADO = {
    "enviado_honduras" => :manifiesto_id,
    "pre_facturado"    => :pre_factura_id,
    "facturado"        => :venta_id,
    "en_reparto"       => :entrega_id
  }.freeze

  # PR-D7.b: helpers para que controller/JS detecten retrocesos en el
  # pipeline. Yusef pidió advertir con modal cuando un supervisor mueve
  # un paquete a un estado anterior (ej. entregado → en_reparto).
  def self.estado_excepcional?(estado)
    ESTADOS_EXCEPCIONALES.include?(estado.to_s)
  end

  def self.transicion_retroceso?(estado_from, estado_to)
    return false if estado_from.blank? || estado_to.blank?
    return false if estado_excepcional?(estado_from) || estado_excepcional?(estado_to)
    i_from = ESTADOS_ORDEN.index(estado_from.to_s)
    i_to   = ESTADOS_ORDEN.index(estado_to.to_s)
    return false unless i_from && i_to
    i_to < i_from
  end

  def self.transicion_pasos_atras(estado_from, estado_to)
    i_from = ESTADOS_ORDEN.index(estado_from.to_s)
    i_to   = ESTADOS_ORDEN.index(estado_to.to_s)
    return 0 unless i_from && i_to
    [ i_from - i_to, 0 ].max
  end

  # Devuelve un preview de lo que se limpiaría si se confirma el
  # retroceso (fechas + FKs presentes en el paquete). Útil para que el
  # modal de confirmación liste los items afectados.
  def retroceso_cleanup_preview(target_estado)
    i_to   = ESTADOS_ORDEN.index(target_estado.to_s)
    i_from = ESTADOS_ORDEN.index(estado.to_s)
    return { fechas: [], fks: [] } unless i_to && i_from && i_to < i_from

    fechas = ESTADOS_ORDEN[(i_to + 1)..i_from].flat_map do |est|
      RETROCESO_CLEANUP_FECHAS_POR_ESTADO[est] || []
    end.select { |attr| self[attr].present? }

    fks = RETROCESO_CLEANUP_FKS_DESDE_ESTADO.filter_map do |min_estado, fk|
      min_idx = ESTADOS_ORDEN.index(min_estado)
      next unless min_idx && i_to < min_idx && self[fk].present?
      fk
    end

    { fechas: fechas, fks: fks }
  end

  # Aplica la limpieza en memoria (no persiste). El save lo hace el flujo
  # normal de update — el callback paper_trail registra el cambio.
  def apply_retroceso_cleanup!(target_estado)
    preview = retroceso_cleanup_preview(target_estado)
    preview[:fechas].each { |attr| self[attr] = nil }
    preview[:fks].each { |fk| self[fk] = nil }
  end

  scope :activos, -> { where.not(estado: %w[anulado entregado retornado desechado]) }
  # Un código escaneado de una caja de split viene como `RMI0002026000042-2`:
  # el número madre más el número de caja. Sin esto, `numero_recepcion ILIKE`
  # no matchea nada — la recepción guardada es `RMI0002026000042` a secas —
  # y escanear en San Pedro devolvería cero resultados.
  #
  # Devuelve `[numero_madre, numero_caja]`, o nil si el término no tiene esa
  # forma. Se exige que el prefijo termine en dígitos para no partir un
  # tracking que traiga guiones (`TBA123-456` no es una caja).
  ESCANEO_DE_CAJA = /\A(?<madre>.*\d)-(?<caja>\d{1,3})\z/
  def self.parsear_codigo_de_caja(term)
    m = ESCANEO_DE_CAJA.match(term.to_s.strip)
    return nil if m.nil?

    [ m[:madre], m[:caja].to_i ]
  end

  scope :buscar, ->(term) {
    term = term.to_s.strip
    return all if term.empty?

    # Escaneo de una caja concreta: cae directo en ella, no en sus hermanas.
    if (parsed = parsear_codigo_de_caja(term))
      madre, caja = parsed
      exacta = where(numero_recepcion: madre, numero_caja: caja)
      return exacta if exacta.exists?

      # No existe esa caja. Puede ser una etiqueta de una caja que se eliminó,
      # o un tracking que casualmente termina en `-2`. En vez de devolver
      # vacío, se busca por la parte de adelante: si es un número madre trae
      # sus hermanas, y si era un tracking lo encuentra igual.
      term = madre
    end

    q = "%#{sanitize_sql_like(term)}%"
    left_joins(:cliente, :tipo_envio, :manifiesto)
      .joins("LEFT OUTER JOIN clientes terceros ON terceros.id = paquetes.tercero_id")
      .where(
        <<~SQL,
          paquetes.tracking ILIKE :q
          OR paquetes.tracking_secundario ILIKE :q
          OR paquetes.guia ILIKE :q
          OR paquetes.numero_recepcion ILIKE :q
          OR paquetes.descripcion ILIKE :q
          OR clientes.codigo ILIKE :q
          OR clientes.nombre ILIKE :q
          OR clientes.apellido ILIKE :q
          OR CONCAT(clientes.nombre, ' ', clientes.apellido) ILIKE :q
          OR CONCAT(clientes.apellido, ' ', clientes.nombre) ILIKE :q
          OR terceros.codigo ILIKE :q
          OR terceros.nombre ILIKE :q
          OR terceros.apellido ILIKE :q
          OR CONCAT(terceros.nombre, ' ', terceros.apellido) ILIKE :q
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
  scope :by_cliente_codigo, ->(text) {
    text = text.to_s.strip
    next all if text.empty?
    q = "%#{sanitize_sql_like(text)}%"
    left_joins(:cliente).where("clientes.codigo ILIKE ?", q)
  }
  scope :by_cliente_nombre, ->(text) {
    text = text.to_s.strip
    next all if text.empty?
    q = "%#{sanitize_sql_like(text)}%"
    left_joins(:cliente).where(
      "clientes.nombre ILIKE :q OR clientes.apellido ILIKE :q OR " \
      "CONCAT(clientes.nombre, ' ', clientes.apellido) ILIKE :q OR " \
      "CONCAT(clientes.apellido, ' ', clientes.nombre) ILIKE :q",
      q: q
    )
  }
  # Búsqueda avanzada: campos extras NO cubiertos por el search bar (`q`).
  # Útil para encontrar paquetes por contenido de notas internas, nombre
  # de sucursal, manifiesto, proveedor, remitente o expedido_por.
  scope :busqueda_avanzada, ->(text) {
    text = text.to_s.strip
    next all if text.empty?

    q = "%#{sanitize_sql_like(text)}%"
    left_joins(:sucursal, :manifiesto, :proveedor)
      .where(<<~SQL, q: q)
        paquetes.notas_internas ILIKE :q
        OR paquetes.notas_al_cliente ILIKE :q
        OR paquetes.notas_consolidacion ILIKE :q
        OR paquetes.notas_retencion ILIKE :q
        OR paquetes.proveedor ILIKE :q
        OR paquetes.remitente ILIKE :q
        OR paquetes.expedido_por ILIKE :q
        OR sucursales.nombre ILIKE :q
        OR sucursales.codigo ILIKE :q
        OR manifiestos.numero ILIKE :q
        OR proveedores.nombre ILIKE :q
      SQL
  }
  scope :by_sucursal, ->(ids) { where(sucursal_id: Array(ids).compact_blank) }
  scope :recibidos_hoy, -> { where(fecha_recibido_miami: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :sin_manifiesto, -> { where(manifiesto_id: nil).where.not(estado: %w[anulado entregado retornado desechado]) }
  scope :facturables, -> { where(estado: "disponible_entrega", pre_factura_id: nil, venta_id: nil) }
  scope :entregables, -> { where(estado: "facturado", entrega_id: nil) }
  # Paquetes sin vincular a ninguna pre_alerta_paquete (sueltos en bodega)
  scope :sin_pre_alerta, -> {
    left_joins(:pre_alerta_paquetes).where(pre_alerta_paquetes: { id: nil })
  }
  # Paquetes vinculados a una pre-alerta específica (vía join table).
  # `.distinct` evita duplicados si el paquete tiene varias pap (raro pero posible).
  scope :by_pre_alerta, ->(pre_alerta_id) {
    joins(:pre_alerta_paquetes)
      .where(pre_alerta_paquetes: { pre_alerta_id: pre_alerta_id })
      .distinct
  }

  before_validation :generate_guia, on: :create, if: -> { guia.blank? }
  before_validation :generate_numero_recepcion, on: :create, if: -> { numero_recepcion.blank? && sucursal_del_numero.present? }
  # Trigger si: (a) marcó recolecta y aún no hay monto, o (b) cambió la
  # tarifa elegida (el cajero corrige zona) → re-sincronizamos monto+moneda.
  before_validation :default_recolecta_monto,
                    if: -> { recolecta_solicitada? && (recolecta_monto.blank? || will_save_change_to_tarifa_recolecta_id?) }
  # PR-D3.b: tracking auto EP-AÑO-SUC-PROV-NNNNNN para paquetes
  # cuyo proveedor es de tipo entrega_personal y el operador no
  # ingresó tracking propio (típico: drivers privados, Uber).
  before_validation :generate_ep_tracking, on: :create, if: :ep_tracking_required?
  # PR-D4.d: tracking auto RC-AÑO-SUC-PROV-NNNNNN cuando CEC mandó
  # un motorista propio a recoletar/comprar al merchant. Trigger:
  # recolecta_solicitada + tracking blank + proveedor (comercio) presente.
  before_validation :generate_rc_tracking, on: :create, if: :rc_tracking_required?
  after_create :ensure_warehouse_receipt, if: -> { warehouse_receipt_id.nil? && numero_recepcion.present? && cliente_id.present? }
  before_save :set_fecha_recibido, if: -> { fecha_recibido_miami.blank? && new_record? }
  before_save :calculate_peso_volumetrico
  before_save :calculate_peso_cobrar
  before_save :track_fecha_disponible, if: :will_save_change_to_estado?
  # En `new_record?` `will_save_change_to_estado?` puede ser falso cuando
  # el estado coincide con el default de la columna ("recibido_miami").
  # Forzamos que la captura inicial de fecha+user funcione también ahí.
  before_save :track_estado_fecha_y_user,
              if: -> { will_save_change_to_estado? || (new_record? && ESTADO_FECHA_MAP.key?(estado)) }
  # PR-D7.m: cuando un admin/supervisor edita manualmente una fecha
  # desde el form (?mode=edit), también actualizar el _by_user_id
  # correspondiente. No aplica a la fecha mapeada al estado que está
  # cambiando — esa la cubre track_estado_fecha_y_user.
  before_save :track_fecha_by_user_on_manual_edit
  # PR-D3.c.2: dropdown híbrido de carrier. Si el usuario escribe un
  # nombre nuevo (no presente en el catálogo), se agrega automáticamente
  # para que la próxima vez aparezca en el dropdown. Yusef:
  # "entre más cosas nos dejes crear, menos te molestaremos".
  after_save :sync_carrier_catalog, if: :saved_change_to_expedido_por?
  after_save :sync_pre_alerta_estados, if: :saved_change_to_estado?
  # Yusef: "al cambiar el manifiesto, las fechas de salida/aduana deben
  # actualizarse al nuevo manifiesto". Mejor como callback (no solo
  # controller) para que el flow desde manifiestos#add_paquete también
  # sincronice las fechas al añadir un paquete a un manifiesto ya enviado.
  before_save :sync_dates_from_manifiesto, if: :manifiesto_id_changed?

  def estado_terminal?
    entregado? || anulado? || retornado? || desechado?
  end

  # Aplica un cambio de servicio: deja el tipo nuevo y guarda de cuál venía.
  #
  # Yusef, 2026-08-08, reproduciendo el caso: marcó "cambio de servicio",
  # eligió CKM, guardó — y el paquete **se quedó en CER**. En las notas de
  # Jorge quedó escrito así: *"cambio de servicio → CER a CKM no funciona"*.
  #
  # El flag solo decía "alguien pidió el cambio"; nada aplicaba el destino, y
  # nada dejaba rastro de cuál era el servicio anterior. Eso último importa
  # porque el cambio **genera un cargo automático** en la pre-factura: cuando
  # el cliente reclama, hay que poder decirle de qué a qué se movió.
  #
  # No hace `save`: el caller decide cuándo persistir, para poder aplicarlo
  # junto con el resto del formulario en un solo `save`.
  def aplicar_cambio_servicio(nuevo_tipo)
    return if nuevo_tipo.nil?
    return if nuevo_tipo.id == tipo_envio_id

    self.tipo_envio_anterior_id = tipo_envio_id
    self.tipo_envio = nuevo_tipo
    self.solicito_cambio_servicio = true
  end

  # El nombre del tercero para mostrar — venga del catálogo o escrito a mano.
  #
  # PR-C6.14. Yusef fue tajante sobre quién digita en Miami: "solo se guarda en
  # esa guía... **no queda grabado en ninguna base de datos de clientes**",
  # porque "el que está digitando ahí no tiene ni voz ni voto para guardar" y
  # "ellos se pueden equivocar y pueden hacer este relajo".
  #
  # Por eso hay dos fuentes y **el catálogo manda**: si alguien eligió un
  # cliente de verdad, ese nombre es el bueno. El texto libre es para el
  # tercero que no está en ninguna cartera, que es el caso normal — "nosotros
  # no tenemos la base de datos completa de los clientes terceros".
  def tercero_display
    tercero&.nombre_completo.presence || tercero_nombre.presence
  end

  # "CER → CKM", para mostrarlo en el detalle y en la pre-factura.
  def cambio_servicio_label
    return nil unless solicito_cambio_servicio? && tipo_envio_anterior
    "#{tipo_envio_anterior.codigo.to_s.upcase} → #{tipo_envio&.codigo.to_s.upcase}"
  end

  # ¿Esta caja ya entró a cobro o salió del almacén? Si sí, borrarla
  # descuadraría una venta o dejaría un entregado sin registro.
  # Se mira el estado **y** los FKs: un paquete puede tener `pre_factura_id`
  # sin que su estado lo diga todavía.
  def cobrada_o_entregada?
    pre_factura_id.present? || venta_id.present? || entrega_id.present? ||
      pre_facturado? || facturado? || entregado? || en_reparto?
  end

  # ── Sub-etiquetas / split de tracking en N bultos ──
  # `numero_caja` (1..N) + `cantidad_paquetes` (total) reusados del módulo 36.
  # Un paquete dividido es un bulto físico identificado como "1/3", "2/3", etc.

  # True si el paquete pertenece a un tracking dividido en >1 bulto.
  def dividido?
    cantidad_paquetes.to_i > 1
  end

  # De qué sucursal sale el prefijo del número de recepción.
  #
  # `sucursal_recepcion` es **dónde se recibió** el paquete — Miami, Panamá,
  # China. `sucursal` es **dónde lo retira el cliente**, y es lo que sale en la
  # etiqueta y lo que usa la búsqueda de tarifa. Son distintas: se recibe en
  # Miami y se retira en Zeron SPS.
  #
  # El fallback a `sucursal` no es pereza: hay flujos que crean paquetes sin
  # pasar por `/etiquetar` (alta manual desde `/paquetes`, seeds, fixtures) y
  # ahí la única sucursal que hay es esa. Sin el fallback esos paquetes se
  # quedarían sin número, que es exactamente el bug que este PR viene a cerrar.
  def sucursal_del_numero
    sucursal_recepcion || sucursal
  end

  # El número de recepción para MOSTRAR. Devuelve nil cuando no hay uno de
  # verdad, para que la vista ponga guión en vez de caer al tracking.
  #
  # Yusef, 2026-08-08, viendo el listado: "esto está malo, porque te está
  # poniendo el tracking y el número de recepción... el número de recepción es
  # como el número de registro". Las columnas son vecinas y salía lo mismo
  # en las dos.
  #
  # Dos formas de no tener recepción de verdad:
  #
  #   1. En blanco — `generate_numero_recepcion` sale temprano cuando el
  #      paquete se guarda sin sucursal.
  #   2. Guardada igual al tracking — data vieja. Jorge: "estos están hechos
  #      porque yo los metí en la base de datos en este formato".
  #
  # El caso 2 se puede detectar sin miedo a falsos positivos: una recepción
  # real es SIEMPRE `<PREFIX><AÑO 7><CORRELATIVO 6>` (ej. `RM0002026000010`),
  # que no se parece a ningún tracking de courier.
  def numero_recepcion_visible
    return nil if numero_recepcion.blank?
    return nil if numero_recepcion.casecmp?(tracking.to_s)

    numero_recepcion
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
    # El número sale de dónde se RECIBIÓ, no de dónde retira el cliente.
    # Mismo fallback que `Paquete#sucursal_del_numero`.
    recepcion    = attrs[:sucursal_recepcion] ||
                   Sucursal.find_by(id: attrs[:sucursal_recepcion_id]) ||
                   sucursal
    numero_madre = generate_numero_recepcion_madre(sucursal: recepcion, attrs: attrs)

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

  # Error de negocio: se quiso borrar una caja que ya entró a cobro o salió.
  class CajaNoEliminable < StandardError; end

  # Cambia un split de N cajas a M. `crear_split!` solo sabía **crear**, así
  # que subir o bajar la cantidad dejaba los registros viejos mezclados con
  # los nuevos. Yusef lo reprodujo dos veces:
  #
  #   · 3 cajas → lo bajó a 2 → quedaron las 3.
  #   · Después lo subió a 5 → "aquí dice dos y aquí dice que son cinco".
  #
  # La regla que acordaron es simple, la cantidad nueva manda:
  #
  #   > **Jorge:** "Si tienes cinco y lo querés cambiar a dos, solo deberían
  #   >  quedar los dos."
  #   > **Yusef:** "Eliminar lo otro. Ajá."
  #
  # **Guarda dura**: si alguna de las cajas a eliminar ya está facturada,
  # pre-facturada o entregada, la operación falla **entera** y no toca nada.
  # Borrar una caja que ya se cobró descuadraría la venta en silencio. Qué
  # hacer en ese caso es pregunta abierta de Yusef; hasta que conteste,
  # bloquear es lo conservador.
  #
  # Devuelve las cajas que quedan, ordenadas por `numero_caja`.
  def self.ajustar_split!(paquete, nueva_cantidad)
    m = nueva_cantidad.to_i
    raise ArgumentError, "la cantidad debe ser >= 1" if m < 1

    transaction do
      hermanas = cajas_del_mismo_split(paquete).to_a
      n = hermanas.size

      if m < n
        sobrantes = hermanas.select { |c| c.numero_caja.to_i > m }
        bloqueadas = sobrantes.select { |c| c.cobrada_o_entregada? }
        if bloqueadas.any?
          raise CajaNoEliminable,
                "No se puede bajar a #{m} cajas: " \
                "#{bloqueadas.map { |c| "la caja #{c.numero_caja} está #{c.estado.humanize.downcase}" }.join(', ')}."
        end
        sobrantes.each(&:destroy!)
        hermanas -= sobrantes
      elsif m > n
        attrs = hermanas.first.attributes.except(
          "id", "created_at", "updated_at", "guia", "numero_caja",
          "cantidad_paquetes", "pre_factura_id", "venta_id", "entrega_id"
        )
        ((n + 1)..m).each do |i|
          hermanas << create!(attrs.merge("numero_caja" => i, "cantidad_paquetes" => m))
        end
      end

      # `update_column` a propósito: `cantidad_paquetes` es un contador, no un
      # cambio de negocio, y pasarlo por validaciones acá dispararía callbacks
      # de estado sobre cajas que no cambiaron de estado.
      hermanas.each { |c| c.update_column(:cantidad_paquetes, m) }
      hermanas.sort_by { |c| c.numero_caja.to_i }
    end
  end

  # Las cajas que comparten número madre. Ojo: NO se agrupa por tracking —
  # dos splits distintos pueden compartir tracking (el courier recicla
  # números), y el índice único es `(numero_recepcion, numero_caja)`.
  def self.cajas_del_mismo_split(paquete)
    return where(id: paquete.id) if paquete.numero_recepcion.blank?

    where(numero_recepcion: paquete.numero_recepcion).order(:numero_caja)
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

  # PR-9.a: solo las tareas marcadas `bloquea_avance` congelan el pipeline.
  # Las auto-creadas desde `pre_alerta_paquetes.instrucciones` nacen con
  # false, porque `crear_paquete_esperado` ya materializó un Paquete y de
  # otro modo trabarían la transición pre_alerta_estado → empacado que hace
  # /etiquetar al recibir el paquete físico.
  def tareas_bloqueantes_pendientes?
    tareas.abiertas.where(bloquea_avance: true).exists?
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
    return unless tareas_bloqueantes_pendientes?

    errors.add(:estado, "no se puede avanzar: el paquete tiene tareas pendientes")
  end

  def sync_pre_alerta_estados
    pre_alerta_paquetes.includes(:pre_alerta).each do |pap|
      pap.pre_alerta&.actualizar_estado_from_paquetes!
    end
  end

  # Copia las fechas del manifiesto al paquete. Si manifiesto_id pasa
  # a nil (paquete sacado del manifiesto), las fechas se limpian — sin
  # manifiesto no hay despacho registrado.
  def sync_dates_from_manifiesto
    if manifiesto
      self.fecha_enviado = manifiesto.fecha_enviado
      self.fecha_aduana  = manifiesto.fecha_aduana
    else
      self.fecha_enviado = nil
      self.fecha_aduana  = nil
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
    origen = sucursal_del_numero
    return if origen.nil?
    prefix = origen.codigo_recepcion_prefix
    return if prefix.blank?

    anio = (fecha_recibido_miami&.year || Time.zone.now.year)
    next_number = NumeroRecepcionCounter.next_for!(sucursal: origen, anio: anio)

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

  # PR-D7.m: lista de fechas que admin/supervisor puede editar
  # manualmente desde el form. Al editar, el `_by_user_id` se
  # actualiza al editor.
  FECHAS_EDITABLES = %i[
    fecha_solicito_recolecta fecha_pre_alerta fecha_recibido_miami
    fecha_empacado fecha_enviado fecha_aduana fecha_consolidando
    fecha_disponible fecha_posible_entrega fecha_en_reparto fecha_entregado
  ].freeze

  def track_fecha_by_user_on_manual_edit
    return unless Current.user
    fecha_del_estado = ESTADO_FECHA_MAP[estado] if will_save_change_to_estado?

    FECHAS_EDITABLES.each do |attr|
      next if attr == fecha_del_estado
      next unless will_save_change_to_attribute?(attr.to_s)
      self["#{attr}_by_user_id"] = Current.user.id
    end
  end

  def set_fecha_recibido
    self.fecha_recibido_miami = Time.current
  end

  # PR-10.a: pasa a usar `VolumetricoCalculator`, que ya implementaba la regla
  # real de Yusef (redondeo a ½ libra con umbrales .10/.60, del spreadsheet de
  # tarifas) y estaba testeada — pero nadie la llamaba. Este método usaba
  # `.round(2)`, así que la calculadora de /etiquetar le mostraba al operario
  # un peso a cobrar distinto del que la pre-factura terminaba cobrando:
  # 8×9×9 = 648 pulg³ facturaba 3.90 lb en vez de 4.0.
  def calculate_peso_volumetrico
    return unless alto.present? && largo.present? && ancho.present?

    in3 = VolumetricoCalculator.pulgadas_cubicas(alto, largo, ancho)
    self.peso_volumetrico = VolumetricoCalculator.vlbs(in3)
  end

  def calculate_peso_cobrar
    if peso.present? || peso_volumetrico.present?
      self.peso_cobrar = [peso || 0, peso_volumetrico || 0].max
    end
  end

  # PR-D1.c + PR-D6.a: cuando se marca recolecta_solicitada y aún no
  # hay monto, autocompletar.
  # - Si el cajero seleccionó una `tarifa_recolecta` del catálogo →
  #   copiar monto+moneda de ahí (Yusef pidió tabla configurable por zona).
  # - Si no eligió tarifa → fallback al default $35 USD del PR-D1.c.
  # El cajero puede sobreescribir el monto manualmente después.
  def default_recolecta_monto
    if tarifa_recolecta.present?
      self.recolecta_monto  = tarifa_recolecta.monto
      self.recolecta_moneda = tarifa_recolecta.moneda
    else
      self.recolecta_monto  = RECOLECTA_TARIFA_DEFAULT_USD
      self.recolecta_moneda ||= "USD"
    end
  end

  # PR-D1.c: si se asigna sub_localidad_actual, debe pertenecer a la
  # sucursal_actual (consistencia referencial — no se puede meter un
  # paquete en una bodega de Zerón si dijiste que está en Humuya).
  def sub_localidad_pertenece_a_sucursal_actual
    return if sub_localidad_actual.blank? || sucursal_actual.blank?
    return if sub_localidad_actual.sucursal_id == sucursal_actual_id
    errors.add(:sub_localidad_actual, "no pertenece a la sucursal actual")
  end

  # PR-D2: si el paquete pasa a estado=retenido, debe tener al menos un
  # motivo seleccionado o `notas_retencion` con detalle libre. Yusef
  # confirmó (2026-04-29 6:42pm) que es OBLIGATORIO en ese estado.
  def retencion_requiere_motivo_o_notas
    has_motivos = paquete_motivos_retencion.any? || motivos_retencion.any?
    has_notas   = notas_retencion.to_s.strip.present?
    return if has_motivos || has_notas
    errors.add(:notas_retencion, "es obligatoria al retener (selecciona motivo o escribe detalle)")
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

  # PR-D3.b: condición para auto-generar tracking EP. Sólo aplica
  # cuando el proveedor es ENTREGA PERSONAL Y el operador no ingresó
  # tracking propio (caso típico: driver privado sin GUID del courier).
  # Si el operador SÍ escribió un tracking (Uber GUID, etc.), se respeta
  # tal cual — no se sobreescribe.
  def ep_tracking_required?
    tracking.blank? &&
      proveedor.present? &&
      proveedor.entrega_personal? &&
      sucursal.present?
  end

  # Genera tracking con formato EP-AÑO-SUC-PROV-NNNNNN. Se llama desde
  # before_validation cuando ep_tracking_required? es true. Si la
  # sucursal no tiene `codigo_ep` configurado, falla limpio con
  # error de validación en lugar de tracking malformado.
  def generate_ep_tracking
    suc_codigo = sucursal&.codigo_ep
    if suc_codigo.blank?
      errors.add(:tracking, "no se puede generar (sucursal #{sucursal&.nombre || sucursal_id} no tiene codigo_ep configurado)")
      return
    end

    anio = (fecha_recibido_miami&.year || Time.zone.now.year)
    next_number = EpCounter.next_for!(anio: anio, sucursal: sucursal, proveedor: proveedor)

    self.tracking = format(
      "EP-%<anio>04d-%<suc>s-%<prov>s-%<num>06d",
      anio: anio, suc: suc_codigo, prov: proveedor.codigo, num: next_number
    )
  end

  # PR-D4.d: condición para auto-generar tracking RC. Aplica cuando
  # CEC mandó un motorista propio a recoletar (no es entrega personal
  # vía driver externo). Mismo formato que EP pero prefijo RC y trigger
  # distinto: recolecta_solicitada + tracking blank + proveedor presente.
  # Si el proveedor es entrega_personal, gana EP (chequeado primero
  # por el orden de los before_validation).
  def rc_tracking_required?
    tracking.blank? &&
      recolecta_solicitada? &&
      proveedor.present? &&
      !proveedor.entrega_personal? &&
      sucursal.present?
  end

  # Genera tracking RC-AÑO-SUC-PROV-NNNNNN. Counter independiente de
  # EpCounter — RC y EP no comparten secuencia.
  def generate_rc_tracking
    suc_codigo = sucursal&.codigo_ep
    if suc_codigo.blank?
      errors.add(:tracking, "no se puede generar (sucursal #{sucursal&.nombre || sucursal_id} no tiene codigo_ep configurado)")
      return
    end

    anio = (fecha_recibido_miami&.year || Time.zone.now.year)
    next_number = RcCounter.next_for!(anio: anio, sucursal: sucursal, proveedor: proveedor)

    self.tracking = format(
      "RC-%<anio>04d-%<suc>s-%<prov>s-%<num>06d",
      anio: anio, suc: suc_codigo, prov: proveedor.codigo, num: next_number
    )
  end

  # PR-D3.c.2: agrega al catálogo de Carriers cualquier nombre nuevo que
  # el usuario escriba en el dropdown híbrido. Match case-insensitive
  # contra el nombre para evitar duplicados (FedEx vs fedex vs FEDEX).
  # Silenciamos errores de validación: si el carrier no se puede crear
  # por algún motivo, el paquete se guarda igual con el string libre.
  def sync_carrier_catalog
    nombre = expedido_por.to_s.strip
    return if nombre.blank?
    return if Carrier.where("LOWER(nombre) = ?", nombre.downcase).exists?

    Carrier.create(nombre: nombre, activo: true)
  end
end
