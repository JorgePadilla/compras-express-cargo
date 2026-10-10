# PR-F1.1 · Fase 15. El libro fiscal: una fila por documento emitido o anulado
# (Acuerdo 481-2017, Art. 53 num. 1 y 5). Es lo que `Fiscal::Ledger` (F1.2)
# escribe y lo que se exporta a la SAR; las columnas son las llaves de
# `Invoicehn::Ledger::JsonlLedger`.
#
# **Solo se agrega.** La base lo garantiza con el trigger
# `asientos_fiscales_solo_agregar`, que rechaza UPDATE y DELETE —también un
# `update_all` o un `delete_all`, que no pasan por acá—; el modelo además se
# vuelve de solo lectura en cuanto existe, para que el error llegue antes y con
# nombre. Una anulación es un asiento nuevo con `evento: "anulacion"`, no un
# cambio al de la emisión.
#
# Ojo en los tests: `TRUNCATE` no dispara triggers de fila, y es como se limpia
# esta tabla en los que corren sin transacción. Por eso tampoco tiene fixtures:
# Rails las carga con `DELETE FROM`.
class AsientoFiscal < ApplicationRecord
  self.table_name = "asientos_fiscales"

  EVENTOS = %w[emision anulacion].freeze
  NUMERO = /\A\d{3}-\d{3}-\d{2}-\d{8}\z/

  belongs_to :punto_de_emision
  # PR-F1.2: opcional. Lo que el libro referencia es el `DocumentoFiscal` que
  # guardó el store; el contrato de la gema registra uno que nunca se guardó.
  belongs_to :documento, polymorphic: true, optional: true
  belongs_to :usuario, class_name: "User", optional: true

  validates :evento, inclusion: { in: EVENTOS }
  validates :tipo_documento, inclusion: { in: Fiscal::TIPOS_DE_DOCUMENTO.keys }
  validates :numero, format: { with: NUMERO, message: "tiene que ser EEE-PPP-TT-NNNNNNNN" }
  validates :cai, :fecha_emision, :moneda, :estado, presence: true
  validates :subtotal, :descuento, :isv, :total, numericality: true

  def readonly?
    persisted? || super
  end
end
