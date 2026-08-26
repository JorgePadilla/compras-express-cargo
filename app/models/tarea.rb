class Tarea < ApplicationRecord
  has_paper_trail  # PR-D7: audit log — asignación, estado, completado_por

  # PR-9.a: una tarea puede colgar del cliente, del paquete, o de ambos.
  # En /etiquetar el paquete todavía no existe cuando el operario escanea,
  # así que la franja de contexto las busca por `cliente_id`.
  belongs_to :paquete, optional: true
  belongs_to :cliente, optional: true
  belongs_to :pre_alerta_paquete, optional: true
  belongs_to :asignado_a, class_name: "User", optional: true
  belongs_to :completado_por, class_name: "User", optional: true
  has_one :reempaque, dependent: :nullify

  enum :estado, {
    pendiente: "pendiente",
    en_proceso: "en_proceso",
    realizada: "realizada"
  }

  # Misma segmentación por área que `User#notas_permanentes_visibles`.
  # `nil` significa "cualquier área la ve".
  DEPARTAMENTOS = %w[miami caja honduras sac].freeze

  # Qué departamentos ve cada rol. Espeja la tabla de notas permanentes
  # para que tareas y notas se filtren igual — que un digitador vea las
  # notas de Miami pero tareas de Caja sería incoherente.
  DEPARTAMENTOS_POR_ROL = {
    "admin"                 => DEPARTAMENTOS,
    "supervisor_miami"      => %w[miami],
    "digitador_miami"       => %w[miami],
    "supervisor_caja"       => %w[caja honduras],
    "cajero"                => %w[caja honduras],
    "supervisor_prefactura" => %w[honduras],
    "sac"                   => %w[sac honduras],
    "entrega_despacho"      => %w[honduras]
  }.freeze

  # `pre_alerta` ya no se escribe: era el origen de las tareas que nacían de
  # las `instrucciones` del cliente, quitado en `PR-C7.41` (`C16-01`). Sigue en
  # la lista por las filas históricas ya realizadas.
  ORIGENES = %w[manual pre_alerta].freeze

  validates :titulo, presence: true
  validates :estado, presence: true
  validates :departamento, inclusion: { in: DEPARTAMENTOS }, allow_nil: true
  validates :origen, inclusion: { in: ORIGENES }
  validate  :requiere_cliente_o_paquete

  before_validation :derivar_cliente_desde_paquete
  before_validation :normalizar_tracking

  scope :abiertas, -> { where.not(estado: "realizada") }
  scope :por_paquete, ->(paquete_id) { where(paquete_id: paquete_id) }
  scope :para_cliente, ->(cliente_id) { where(cliente_id: cliente_id) }

  # Tareas que un usuario puede ver: las de su(s) departamento(s) más las
  # que no tienen departamento asignado (visibles para todos).
  scope :visibles_para, ->(user) {
    deptos = DEPARTAMENTOS_POR_ROL.fetch(user&.rol, [])
    where(departamento: deptos + [ nil ])
  }

  # Las tareas que nacieron de las `instrucciones` del cliente (`PR-9`) y nadie
  # marcó como hechas. Yusef, 2026-08-25: *"el cliente no puede poner una
  # tarea, solo nosotros"*. Las ya realizadas se quedan: llevan quién y cuándo
  # las marcó, y esa evidencia no se toca. `destroy!` y no `delete_all` para
  # que paper_trail guarde la versión de cada una.
  #
  # Devuelve los títulos borrados, para que la migración informe cuáles tocó.
  def self.borrar_las_nacidas_de_instrucciones!
    nacidas = where(origen: "pre_alerta").abiertas.order(:id).to_a
    nacidas.each(&:destroy!)
    nacidas.map(&:titulo)
  end

  # C17-02: las tareas que se dejaron desde la franja de /etiquetar mientras
  # se recibía este paquete —con su tracking y todavía sin paquete— pasan a
  # colgar de él. También por el secundario: `trackings_reconciliados` mueve
  # el escaneado al secundario cuando el esperado tenía otro tracking (el caso
  # USPS), y lo que la franja guardó fue el escaneado. Espejo de
  # `PreAlertaPaquete.link_tracking!`. Devuelve cuántas ató.
  def self.atar_al_paquete!(paquete)
    return 0 if paquete.nil? || paquete.cliente_id.nil?

    trackings = [ paquete.tracking, paquete.tracking_secundario ]
                  .compact_blank.map { |t| t.to_s.strip.upcase }.uniq
    return 0 if trackings.empty?

    where(cliente_id: paquete.cliente_id, paquete_id: nil, tracking: trackings)
      .update_all(paquete_id: paquete.id)
  end

  def completar!(user)
    update!(estado: "realizada", completado_por: user, completada_en: Time.current)
  end

  def reabrir!
    update!(estado: "pendiente", completado_por: nil, completada_en: nil)
  end

  def iniciar!(user = nil)
    update!(estado: "en_proceso", asignado_a: asignado_a || user)
  end

  def departamento_label
    return "Todas las áreas" if departamento.blank?
    { "miami" => "Miami", "caja" => "Caja", "honduras" => "Honduras", "sac" => "SAC" }
      .fetch(departamento, departamento.humanize)
  end

  private

  # Si viene solo con paquete, heredamos su cliente para que la franja la
  # encuentre por `cliente_id` sin tener que hacer join.
  def derivar_cliente_desde_paquete
    self.cliente_id ||= paquete&.cliente_id
  end

  def normalizar_tracking
    self.tracking = tracking.to_s.strip.upcase.presence
  end

  def requiere_cliente_o_paquete
    return if cliente_id.present? || paquete_id.present?

    errors.add(:base, "la tarea debe pertenecer a un cliente o a un paquete")
  end
end
