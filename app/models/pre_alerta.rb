class PreAlerta < ApplicationRecord
  self.table_name = "pre_alertas"
  has_paper_trail  # PR-D1.a: audit log

  belongs_to :cliente
  belongs_to :tipo_envio
  has_many :pre_alerta_paquetes, dependent: :destroy

  enum :estado, {
    pre_alerta: "pre_alerta",
    recibido: "recibido",
    enviado: "enviado",
    en_aduana: "en_aduana",
    disponible: "disponible",
    facturado: "facturado",
    anulado: "anulado"
  }

  enum :creado_por_tipo, {
    cliente: "cliente",
    usuario: "usuario"
  }, prefix: :creado_por

  validates :numero_documento, presence: true, uniqueness: { case_sensitive: false }
  validates :estado, presence: true
  validates :titulo, presence: true
  validate :respect_max_paquetes_por_accion
  validate :sin_consolidar_va_un_solo_paquete
  # ── Las reglas del servicio ──────────────────────────────────────────────
  #
  # Jorge, 2026-08-20: *"faltan las reglas de servicio, que son importantísimas,
  # con respecto a si se puede con reempaque y consolidación. Revisá la parte de
  # cliente y aplicale las reglas al admin"*.
  #
  # El portal las respetaba las tres y admin ninguna, así que **admin podía
  # grabar lo que el portal hace imposible**: una CKA marcada «con reempaque» y
  # «consolidado», cuando CKA ni reempaca ni consolida.
  #
  # Van en el modelo y no en la vista porque una regla que vive en una pantalla
  # es una regla que la otra no tiene — que es exactamente cómo llegamos acá.
  before_validation :heredar_reempaque_del_servicio,
                    if: -> { new_record? || tipo_envio_id_changed? }
  validate :consolidado_solo_si_el_servicio_lo_permite,
           if: -> { new_record? || consolidado_changed? || tipo_envio_id_changed? }

  accepts_nested_attributes_for :pre_alerta_paquetes, allow_destroy: true,
    reject_if: ->(attrs) {
      attrs["tracking"].blank? &&
      attrs["descripcion"].blank? &&
      attrs["instrucciones"].blank?
    }

  scope :activas, -> { where(deleted_at: nil).where.not(estado: "anulado") }
  scope :buscar, ->(term) {
    left_joins(:cliente).where(
      "pre_alertas.numero_documento ILIKE :q OR clientes.codigo ILIKE :q OR clientes.nombre ILIKE :q OR pre_alertas.titulo ILIKE :q OR pre_alertas.proveedor ILIKE :q",
      q: "%#{sanitize_sql_like(term)}%"
    )
  }
  scope :by_estado, ->(estado) { where(estado: estado) }
  scope :by_cliente, ->(cliente_id) { where(cliente_id: cliente_id) }
  scope :by_tipo_envio, ->(tipo_envio_id) { where(tipo_envio_id: tipo_envio_id) }
  scope :recientes, -> { order(created_at: :desc) }
  scope :vacias, -> { left_joins(:pre_alerta_paquetes).where(pre_alerta_paquetes: { id: nil }) }
  scope :solo_anulados, -> { where(estado: "anulado") }
  scope :soft_deleted, -> { where.not(deleted_at: nil) }

  before_validation :assign_default_tipo_envio, on: :create
  before_validation :generate_numero_documento, on: :create, if: -> { numero_documento.blank? }

  after_update :cascade_anular_a_paquetes, if: :saved_change_to_estado?

  PAQUETE_TO_PRE_ALERTA_ESTADO = {
    "recibido_miami"     => "recibido",
    "empacado"           => "recibido",
    "enviado_honduras"   => "enviado",
    "en_aduana"          => "en_aduana",
    "disponible_entrega" => "disponible",
    "facturado"          => "facturado",
    "en_reparto"         => "facturado",
    "entregado"          => "facturado"
  }.freeze

  ESTADO_PIPELINE = %w[pre_alerta recibido enviado en_aduana disponible facturado].freeze

  def actualizar_estado_from_paquetes!
    return if anulado?

    paquetes = pre_alerta_paquetes.where.not(paquete_id: nil).includes(:paquete).filter_map(&:paquete)
    return if paquetes.empty?

    mapped = paquetes.filter_map { |p| PAQUETE_TO_PRE_ALERTA_ESTADO[p.estado] }
    return if mapped.empty?

    min_idx = mapped.map { |e| ESTADO_PIPELINE.index(e) }.compact.min
    return if min_idx.nil?

    cur_idx = ESTADO_PIPELINE.index(estado)
    return if cur_idx.nil? || min_idx <= cur_idx

    update!(estado: ESTADO_PIPELINE[min_idx])
  end

  # A7-19. La contraparte de `Paquete#sync_pre_alerta_tipo_envio`: cuando Miami
  # recibe el paquete con otro servicio, la pre-alerta lo sigue.
  #
  # Se sincroniza **solo cuando no hay duda**. Si todos los paquetes vinculados
  # coinciden, la pre-alerta toma ese tipo. Si divergen —dos cambios de servicio
  # distintos dentro de la misma pre-alerta— no se adivina: se deja como está y
  # queda anotado, porque elegir uno de los dos sería inventarle un servicio al
  # cliente.
  #
  # Va con `update` y no `update!` a propósito: esto corre dentro de un
  # `after_save` del paquete, y `respect_max_paquetes_por_accion` puede rechazar
  # el tipo nuevo (por ejemplo CKM, que solo admite un paquete). Que la
  # pre-alerta no se pueda sincronizar **no puede tumbar la recepción del
  # paquete** — se anota y se sigue.
  def sincronizar_tipo_envio_desde_paquetes!
    return if anulado?

    tipos = pre_alerta_paquetes.where.not(paquete_id: nil).includes(:paquete)
                               .filter_map { |pap| pap.paquete&.tipo_envio_id }.uniq
    return if tipos.empty?

    if tipos.size > 1
      append_historial!("Los paquetes de esta pre-alerta quedaron con tipos de envío distintos; no se sincronizó.")
      return
    end

    nuevo_id = tipos.first
    return if nuevo_id == tipo_envio_id

    anterior = tipo_envio&.nombre || "sin definir"
    nuevo = TipoEnvio.find_by(id: nuevo_id)

    if update(tipo_envio_id: nuevo_id)
      append_historial!("Tipo de envío: #{anterior} → #{nuevo&.nombre} (así se recibió el paquete en Miami).")
    else
      append_historial!("No se pudo pasar a #{nuevo&.nombre}: #{errors.full_messages.to_sentence}.")
      reload
    end
  end

  def anular!
    update!(estado: "anulado")
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def vacia?
    pre_alerta_paquetes.empty?
  end

  def consolidando?
    consolidado? && !finalizado?
  end

  # Estados where a linked paquete being at this estado or later locks notas_grupo editing.
  # Mirrors the "BLOCKED" row of the move/delete rules matrix.
  ESTADOS_QUE_BLOQUEAN_NOTAS = %w[
    en_aduana disponible_entrega facturado en_reparto entregado
    retenido retornado desechado anulado
  ].freeze

  def notas_editables?
    return false unless consolidando?

    pre_alerta_paquetes.includes(:paquete).none? do |pap|
      pap.paquete && ESTADOS_QUE_BLOQUEAN_NOTAS.include?(pap.paquete.estado)
    end
  end

  def append_historial!(entry)
    current = historial.to_s
    new_historial = current.present? ? "#{current}\n#{entry}" : entry
    update_column(:historial, new_historial)
  end

  def tipo_envio_descripcion
    return "" unless tipo_envio
    modalidad = tipo_envio.modalidad&.capitalize || "—"
    tipo_envio.con_reempaque ? "#{modalidad} con Reempaque" : "#{modalidad} sin Reempaque"
  end

  def save(**args, &block)
    super
  rescue ActiveRecord::RecordNotUnique => e
    raise unless new_record? && e.message.include?("numero_documento") && (@_doc_retries ||= 0) < 3
    @_doc_retries += 1
    self.numero_documento = nil
    generate_numero_documento
    retry
  end

  private

  def assign_default_tipo_envio
    return if tipo_envio_id.present? || tipo_envio.present?
    self.tipo_envio = TipoEnvio.activos.find_by(codigo: "cer")
  end

  # `con_reempaque` **no es una decisión, es una consecuencia**.
  #
  # El portal ya lo hacía —`wizard["con_reempaque"] = tipo.con_reempaque`— y el
  # propio `tipo_envio_descripcion` de acá abajo ya lo asumía: dice «con
  # Reempaque» leyendo el flag **del servicio**, no el de la fila. O sea que la
  # columna y la descripción podían contradecirse sobre la misma pre-alerta.
  #
  # Se recalcula al crear y al cambiar de servicio, no en cada guardado: reescribir
  # el dato de una pre-alerta vieja porque alguien le corrigió el título sería
  # tocar historia que nadie pidió tocar.
  def heredar_reempaque_del_servicio
    return if tipo_envio.nil?

    self.con_reempaque = tipo_envio.con_reempaque
  end

  # Consolidar es del servicio, no del que llena el formulario.
  #
  # En el portal el paso de consolidación **no existe** para los que no lo
  # permiten (`cuenta/pre_alertas_controller`: si no es `consolidable`, fuerza
  # `consolidado = false` y salta al paso 3). En admin era una casilla suelta.
  #
  # Con el guard de siempre: al crear, o cuando cambian el flag o el servicio.
  # Una pre-alerta vieja que ya quedó así se sigue pudiendo editar — es la trampa
  # del método de prepago y la del consolidado.
  def consolidado_solo_si_el_servicio_lo_permite
    return unless consolidado?
    return if tipo_envio.nil? || tipo_envio.consolidable?

    errors.add(:consolidado, "no aplica: #{tipo_envio.nombre} no se consolida")
  end

  # ── Las que ya estaban grabadas ──────────────────────────────────────────
  #
  # Antes de que las reglas existieran, admin podía marcar «con reempaque» y
  # «consolidado» sobre cualquier servicio. Este método las alinea con el suyo.
  #
  # Vive acá y no adentro del archivo de migración por lo mismo que
  # `Paquete.reconciliar_fantasmas!`: un método se puede testear —incluida la
  # idempotencia, llamándolo dos veces— y un archivo de migración no.
  #
  # **No toca las anuladas, las facturadas ni las borradas.** Ahí el dato es
  # historia de lo que se cobró, no una bandera que corregir.
  #
  # Devuelve `[[numero_documento, qué se corrigió], …]`.
  ESTADOS_QUE_NO_SE_CORRIGEN = %w[anulado facturado].freeze

  def self.alinear_con_su_servicio!
    corregidas = []

    where(deleted_at: nil)
      .where.not(estado: ESTADOS_QUE_NO_SE_CORRIGEN)
      .includes(:tipo_envio)
      .find_each do |pa|
      te = pa.tipo_envio
      next if te.nil?

      arreglos = []
      arreglos << "reempaque: #{pa.con_reempaque} → #{te.con_reempaque}" if pa.con_reempaque? != te.con_reempaque?
      arreglos << "consolidado: sí → no" if pa.consolidado? && !te.consolidable?
      next if arreglos.empty?

      # `update_columns` a propósito: esto **corrige** el dato para que cuadre
      # con su servicio, y pasarlo por las validaciones nuevas lo rechazaría
      # justamente por estar mal — que es lo que se viene a arreglar.
      pa.update_columns(con_reempaque: te.con_reempaque,
                        consolidado: pa.consolidado? && te.consolidable?)
      corregidas << [ pa.numero_documento, arreglos.join(" · ") ]
    end

    corregidas
  end

  def respect_max_paquetes_por_accion
    return unless tipo_envio&.single_package?
    active_paquetes = pre_alerta_paquetes.reject(&:marked_for_destruction?)
    return if active_paquetes.size <= 1
    errors.add(:base, "#{tipo_envio.nombre} solo permite 1 paquete por pre-alerta")
  end

  # Sin consolidar, una pre-alerta lleva **un** paquete.
  #
  # Yusef, probando staging: *"no marqué consolidado y me deja agregar más de 1,
  # siempre en admin"*. La regla existía pero **solo en la vista del portal**:
  # el botón «Agregar Otro Paquete» aparece únicamente si consolidaste. Admin no
  # tenía nada, así que las dos pantallas decían cosas distintas.
  #
  # ── Por qué no valida siempre ──────────────────────────────────────────
  #
  # Si corriera en cada guardado, las pre-alertas que YA están así —sin
  # consolidar y con varios paquetes— quedarían imposibles de guardar: abrir una
  # para corregirle el título la trabaría con un error de algo que nadie tocó.
  # Es la misma trampa que salió con el método de prepago.
  #
  # Corre cuando la pre-alerta es nueva o cuando cambia la cantidad de paquetes,
  # que es cuando alguien está tomando la decisión.
  def sin_consolidar_va_un_solo_paquete
    return if consolidado?

    activos = pre_alerta_paquetes.reject(&:marked_for_destruction?)
    return if activos.size <= 1
    return unless new_record? || activos.any? { |p| p.new_record? }

    errors.add(:base, "Sin consolidar, la pre-alerta lleva un solo paquete. " \
                      "Marcá «Consolidado» para agrupar varios.")
  end

  def generate_numero_documento
    next_number = (self.class.where("numero_documento ~ '^PA-[0-9]+$'")
      .maximum(Arel.sql("CAST(SUBSTRING(numero_documento FROM 4) AS INTEGER)")) || 0) + 1
    self.numero_documento = "PA-#{next_number.to_s.rjust(6, '0')}"
  end

  # Cuando la PA pasa a `anulado`, anular en cascada los paquetes
  # esperados (los que aún no han llegado físicamente a Miami).
  # Usa update_all para saltar callbacks — la PA ya está anulada y no
  # debe re-sincronizarse desde sus paquetes.
  def cascade_anular_a_paquetes
    return unless estado == "anulado"
    paquete_ids = pre_alerta_paquetes.pluck(:paquete_id).compact
    return if paquete_ids.empty?
    Paquete.where(id: paquete_ids, estado: "pre_alerta_estado")
           .update_all(estado: "anulado", updated_at: Time.current)
  end
end
