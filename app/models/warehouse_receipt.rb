# Warehouse Receipt — documento que el almacén emite al recibir un tracking.
# Es el "número madre" que agrupa N paquetes (cajas) del mismo tracking
# físico (split). Equivalente conceptual al `paquetes.numero_recepcion`
# actual; en parte 2 de este PR se migran los datos y se hace la asociación
# `Paquete belongs_to :warehouse_receipt`.
#
# Spec: docs/warehouse_receipt_fields.md (Yusef 2026-04-29).
class WarehouseReceipt < ApplicationRecord
  STATUSES = %w[draft received printed dispatched delivered abandoned].freeze
  REPACKAGING_TYPES = %w[sin_reempacar reempacar reempacar_unitario].freeze

  # `consignee` (Cliente destinatario) es REQUERIDO: todo WR se emite a
  # nombre de un cliente concreto que recibirá la mercancía. Si no hay
  # consignee, el documento no tiene sentido de negocio.
  #
  # Las demás asociaciones quedan opcionales:
  #   - `supplier` puede ser nil (caso ENTREGA PERSONAL sin proveedor real registrado).
  #   - `agent` es opcional por diseño (mayoría de WRs no llevan agent).
  #   - `user`, `pre_alerta`, `sucursal` pueden faltar en escenarios edge
  #     (data legacy, WRs creados via console, paquetes sin pre-alerta).
  belongs_to :consignee,  class_name: "Cliente"
  belongs_to :supplier,   optional: true
  belongs_to :agent,      optional: true
  belongs_to :user,       optional: true
  belongs_to :pre_alerta, optional: true
  belongs_to :sucursal,   optional: true

  # PR-5c.5p2: las N cajas del split (mismo numero_recepcion) apuntan al
  # mismo WR. Para paquete single, hay 1 sola fila apuntando.
  has_many :paquetes, dependent: :nullify

  validates :receipt_number, presence: true, uniqueness: { case_sensitive: false }
  validates :issued_on,      presence: true
  # `consignee` ya es requerido por `belongs_to` non-optional. La validación
  # explícita la hace evidente en el modelo y produce el mismo mensaje de
  # error sin tener que leer la línea del belongs_to.
  validates :consignee,      presence: true
  validates :status,         inclusion: { in: STATUSES }
  validates :repackaging_type, inclusion: { in: REPACKAGING_TYPES, allow_nil: true }
  validates :declared_value_currency, presence: true

  normalizes :receipt_number, with: ->(n) { n.to_s.strip.upcase }

  scope :recientes,   -> { order(issued_on: :desc, id: :desc) }
  scope :activos,     -> { where.not(status: %w[abandoned]) }
  scope :for_status,  ->(s) { where(status: s) }

  # Calcula los totales en KG y m³ para mostrar en el WR (no se almacenan).
  LB_TO_KG   = 0.4535924
  CUFT_TO_M3 = 0.0283168

  def total_weight_kg
    (total_weight_lb.to_f * LB_TO_KG).round(2)
  end

  def total_volumetric_weight_kg
    (total_volumetric_weight_lb.to_f * LB_TO_KG).round(2)
  end

  def total_volume_m3
    (total_volume_cuft.to_f * CUFT_TO_M3).round(4)
  end

  # `declared_value_cents` (Integer) es la fuente de verdad en BD; los
  # accessors `declared_value` (Float) leen/escriben sobre cents para que
  # el caller pueda usar el monto en dólares. Si código consumidor escribe
  # `declared_value_cents` directamente (ej. una migración), el getter
  # `declared_value` derivado sigue siendo consistente porque siempre
  # convierte desde cents.
  def declared_value
    declared_value_cents.to_i / 100.0
  end

  def declared_value=(amount)
    self.declared_value_cents = (amount.to_f * 100).round
  end

  def abandoned_at
    issued_on && (issued_on + 30.days)
  end

  def to_s
    receipt_number
  end
end
