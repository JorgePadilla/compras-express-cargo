# PR-F2.2a · Fase 15. La factura SAR (Acuerdo 481-2017), dormida: la emite
# `Fiscal::EmitirFactura` y la anula `Fiscal::AnularFactura`, y todavía no la
# llama ninguna pantalla. Jorge, 2026-10-10: *modelo nuevo `Factura` que
# reemplaza a `Venta`*; el corte —pagos, saldo, entregas, portal— es F2.4.
#
# Nace **una sola vez, ya numerada**: la construye `EmitirFactura` sin número y
# se la pasa a la gema como `borrador:`; el store la estampa
# (`estampar_documento_fiscal`) y la guarda en el mismo paso en que guarda el
# documento fiscal, adentro del candado del correlativo. Así no existe una
# factura sin número ni un número sin factura.
#
# Lo fiscal no se edita después: lo frena la base (trigger
# `facturas_fiscal_inmutable`). Se corrige anulando (Art. 41).
class Factura < ApplicationRecord
  has_paper_trail

  ESTADOS = [ Invoicehn::Invoice::STATUS_ISSUED, Invoicehn::Invoice::STATUS_ANNULLED ].freeze
  TIPO = "01".freeze

  belongs_to :punto_de_emision
  belongs_to :cliente
  belongs_to :creado_por, class_name: "User", optional: true
  has_many :factura_items, dependent: :restrict_with_exception, inverse_of: :factura
  has_many :pre_facturas, dependent: :restrict_with_exception
  has_one :documento_fiscal, as: :documentable, dependent: :restrict_with_exception
  has_many :autorizaciones, as: :documento, dependent: :restrict_with_exception

  validates :numero, :fecha_emision, :cai, :rango_inicio, :rango_fin, :fecha_limite_emision,
            :cliente_nombre, presence: true
  validates :estado, inclusion: { in: ESTADOS }
  validates :moneda, inclusion: { in: CurrencyAware::MONEDAS }

  # F2.4 incrementa acá el saldo del cliente. El candado va igual desde ya, y
  # en este lugar: después del correlativo (la creación corre adentro de
  # `Fiscal::Sequence#allocate`), en el orden pre-facturas → correlativo →
  # cliente que usa toda la emisión.
  before_create { cliente.lock! }

  scope :emitidas, -> { where(estado: Invoicehn::Invoice::STATUS_ISSUED) }
  scope :recientes, -> { order(fecha_emision: :desc, numero: :desc) }

  def emitida? = estado == Invoicehn::Invoice::STATUS_ISSUED
  def anulada? = estado == Invoicehn::Invoice::STATUS_ANNULLED

  # Lo que la factura tiene que sumar; lo pone `EmitirFactura` antes de pasarla
  # a la gema, y `estampar_documento_fiscal` lo compara con lo que la gema
  # calculó. No es columna.
  attr_accessor :total_esperado

  # ── El contrato con `Fiscal::Store` (ver su cabecera) ────────────────────

  # Copia lo que la gema decidió. Solo asigna: el store hace el `save!`.
  #
  # El tripwire: si la gema suma otra cosa que la pre-factura, no se factura.
  # Corre adentro del bloque del correlativo, así que el error deshace todo y
  # el número no se consume.
  def estampar_documento_fiscal(invoice)
    if invoice.annulled?
      self.estado = invoice.status
      self.anulada_at = Time.current
      self.motivo_anulacion = invoice.annulment_reason
      return
    end

    verificar_total!(invoice) if new_record?
    assign_attributes(
      numero: invoice.correlative.to_s, estado: invoice.status, fecha_emision: invoice.issue_date,
      cai: invoice.authorization.cai, rango_inicio: invoice.authorization.range_start.to_s,
      rango_fin: invoice.authorization.range_end.to_s, fecha_limite_emision: invoice.authorization.limit_date,
      cliente_nombre: invoice.customer.respond_to?(:display_name) ? invoice.customer.display_name : invoice.customer.name,
      cliente_rtn: invoice.customer.rtn&.to_s,
      cliente_identificacion: (invoice.customer.identification_line.presence unless invoice.customer.rtn),
      tasa_cambio: invoice.exchange_rate&.rate,
      subtotal: invoice.summary.gross.amount, descuento: invoice.discount.amount,
      impuesto: invoice.isv_total.amount, total: invoice.total.amount,
      desglose: invoice.summary.to_h, anulada_at: nil, motivo_anulacion: nil
    )
  end

  # F2.3 agrega `pagos.factura_id`; desde ahí esto mira de verdad. Antes, una
  # factura dormida no tiene cómo recibir pagos.
  def pagos_completados?
    return false unless Pago.column_names.include?("factura_id")

    Pago.where(factura_id: id, estado: "completado").exists?
  end

  def to_invoicehn
    documento_fiscal&.to_invoicehn
  end

  private

  def verificar_total!(invoice)
    return if total_esperado.nil?
    return if invoice.total.amount == total_esperado.to_d

    raise Fiscal::TotalesNoCuadran,
          "la gema da #{invoice.total.amount.to_s('F')} y las pre-facturas #{total_esperado.to_d.to_s('F')}: " \
          "no se factura"
  end
end
