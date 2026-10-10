# PR-F1.2 · Fase 15. Un documento fiscal emitido —factura, nota de crédito o de
# débito— tal como lo guarda la gema `invoicehn`: `documento` es `Invoice#to_h`
# y `Fiscal::Store#find` lo vuelve a armar con `Invoice.from_h`.
#
# Una tabla para los tres tipos porque la gema busca por número sin saber de
# qué tipo es (la referencia de una nota apunta a una factura). El registro de
# negocio —la Factura de F2.2a, una nota— cuelga por `documentable`.
#
# No es solo-agregar como `asientos_fiscales`: la forma ANULADA reemplaza a la
# emitida (Art. 41), y la gema borra el documento si el libro rechaza su
# asiento (así no queda un documento sin su número contado). Por eso lo que no
# se puede borrar es el libro, no esto; y por eso tiene paper_trail.
class DocumentoFiscal < ApplicationRecord
  has_paper_trail
  self.table_name = "documentos_fiscales"

  ESTADOS = [ Invoicehn::Invoice::STATUS_ISSUED, Invoicehn::Invoice::STATUS_ANNULLED ].freeze

  belongs_to :punto_de_emision
  belongs_to :documentable, polymorphic: true, optional: true

  validates :numero, presence: true, uniqueness: true
  validates :tipo_documento, inclusion: { in: Fiscal::TIPOS_DE_DOCUMENTO.keys }
  validates :estado, inclusion: { in: ESTADOS }
  validates :fecha_emision, :cai, :documento, presence: true

  def to_invoicehn
    Invoicehn::Invoice.from_h(documento)
  end
end
