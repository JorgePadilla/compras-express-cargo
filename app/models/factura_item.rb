# PR-F2.2a · Una línea de la factura SAR: la copia de la línea de pre-factura
# de la que salió (D5 de FISCAL.md), con su subtotal ya cobrado. Lo que la gema
# recibió de ella es `quantity: 1, unit_price: subtotal` (D3, `Fiscal::Totales`).
# No se cambia ni se borra: lo frena la base (`factura_items_inmutables`).
class FacturaItem < ApplicationRecord
  has_paper_trail

  belongs_to :factura, inverse_of: :factura_items
  belongs_to :pre_factura_item, optional: true
  belongs_to :paquete, optional: true
  belongs_to :bulto, optional: true

  validates :concepto, presence: true
  validates :subtotal, :descuento_monto, numericality: { greater_than_or_equal_to: 0 }
  validates :tratamiento, presence: true

  # Para `Fiscal::Totales`, que arma la línea de la gema igual que para la
  # pre-factura.
  def tratamiento_fiscal = tratamiento.to_sym
end
