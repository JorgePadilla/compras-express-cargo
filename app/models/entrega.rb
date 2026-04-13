class Entrega < ApplicationRecord
  TIPOS = %w[retiro_oficina domicilio].freeze
  ESTADOS = %w[pendiente en_reparto entregado anulado].freeze

  belongs_to :cliente
  belongs_to :repartidor, class_name: "User", optional: true
  belongs_to :creado_por, class_name: "User", optional: true
  has_many :paquetes, dependent: :nullify

  validates :numero, presence: true, uniqueness: { case_sensitive: false }
  validates :tipo_entrega, presence: true, inclusion: { in: TIPOS }
  validates :estado, presence: true, inclusion: { in: ESTADOS }
  validates :receptor_nombre, presence: true
  validates :receptor_identidad, presence: true
  validates :direccion_entrega, presence: true, if: -> { tipo_entrega == "domicilio" }
  validates :repartidor, presence: true, if: -> { tipo_entrega == "domicilio" }

  before_validation :generate_numero, on: :create, if: -> { numero.blank? }

  scope :recientes, -> { order(created_at: :desc) }
  scope :activas, -> { where.not(estado: "anulado") }
  scope :by_estado, ->(estado) { where(estado: estado) }
  scope :by_cliente, ->(cliente_id) { where(cliente_id: cliente_id) }
  scope :by_repartidor, ->(user_id) { where(repartidor_id: user_id) }
  scope :del_dia, -> { where(created_at: Time.current.all_day) }
  scope :buscar, ->(term) {
    left_joins(:cliente).where(
      "entregas.numero ILIKE :q OR clientes.codigo ILIKE :q OR clientes.nombre ILIKE :q OR entregas.receptor_nombre ILIKE :q",
      q: "%#{sanitize_sql_like(term)}%"
    )
  }

  ESTADOS.each do |estado|
    define_method("#{estado}?") { self.estado == estado }
  end

  def despachar!
    return false unless pendiente?

    transaction do
      update!(estado: "en_reparto", despachado_at: Time.current)
      paquetes.each { |p| p.update!(estado: "en_reparto") }
    end
    true
  end

  def entregar!
    return false unless en_reparto?

    transaction do
      update!(estado: "entregado", entregado_at: Time.current)
      paquetes.each { |p| p.update!(estado: "entregado") }
    end
    true
  end

  def anular!
    return false if entregado?
    return false if anulado?

    transaction do
      paquetes.each { |p| p.update!(estado: "facturado", entrega_id: nil) }
      update!(estado: "anulado")
    end
    true
  end

  def self.build_from_paquetes(cliente, paquete_ids, tipo_entrega:, receptor_nombre:, receptor_identidad:, direccion_entrega: nil, repartidor_id: nil, creado_por: nil, notas: nil)
    entrega = new(
      cliente: cliente,
      tipo_entrega: tipo_entrega,
      receptor_nombre: receptor_nombre,
      receptor_identidad: receptor_identidad,
      direccion_entrega: direccion_entrega,
      repartidor_id: repartidor_id,
      creado_por: creado_por,
      notas: notas
    )

    entrega.paquetes = cliente.paquetes.entregables.where(id: paquete_ids)

    entrega
  end

  private

  def generate_numero
    next_number = self.class.connection.select_value("SELECT nextval('entregas_numero_seq')")
    self.numero = "EN-#{next_number.to_s.rjust(6, '0')}"
  end
end
