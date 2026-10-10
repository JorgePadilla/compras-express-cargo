# PR-F1.1 · Fase 15. El último número emitido por punto de emisión y tipo de
# documento: los 8 dígitos finales de `EEE-PPP-TT-NNNNNNNN`.
#
# Lo mueve solo `Fiscal::Sequence` (F1.2): `SELECT … FOR UPDATE`, asigna
# `ultimo + 1`, y escribe `ultimo` recién cuando el documento quedó guardado,
# todo en una transacción. Así un documento que falla no deja hueco, que la SAR
# no acepta.
#
# Sin paper_trail: es un contador que se toca en cada factura, y lo emitido
# queda en `asientos_fiscales`, que no se puede borrar.
class CorrelativoFiscal < ApplicationRecord
  self.table_name = "correlativos_fiscales"

  belongs_to :punto_de_emision

  validates :tipo_documento, inclusion: { in: Fiscal::TIPOS_DE_DOCUMENTO.keys }
  validates :tipo_documento, uniqueness: { scope: :punto_de_emision_id }
  validates :ultimo, numericality: { only_integer: true, greater_than_or_equal_to: 0,
                                     less_than_or_equal_to: Fiscal::CORRELATIVO_MAXIMO }

  def siguiente
    ultimo + 1
  end
end
