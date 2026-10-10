require "test_helper"
require_relative "../support/con_quien_factura"

# PR-F2.2a · Lo fiscal de una factura no se cambia ni se borra: lo frena la
# base, aunque se saltee el modelo.
class FacturaTest < ActiveSupport::TestCase
  include ConQuienFactura

  setup do
    @factura = Fiscal::EmitirFactura.new(pre_facturas: [ pre_facturas(:pendiente_maria) ], por: quien_factura).call
  end

  def rechazado(&)
    error = assert_raises(ActiveRecord::StatementInvalid) { Factura.transaction(requires_new: true, &) }
    assert_kind_of PG::RestrictViolation, error.cause
    error
  end

  test "el número, el CAI, el cliente y los montos no se cambian" do
    { numero: "000-001-01-00000099", cai: "OTRO", total: 1, cliente_id: clientes(:juan).id,
      fecha_emision: Fiscal.hoy - 1, desglose: { "x" => 1 } }.each do |columna, valor|
      rechazado { @factura.update_columns(columna => valor) }
    end
    assert_equal "000-001-01-00000001", @factura.reload.numero
  end

  test "la factura no se borra, ni sus líneas se tocan" do
    rechazado { Factura.where(id: @factura.id).delete_all }
    rechazado { FacturaItem.where(factura_id: @factura.id).update_all(subtotal: 0) }
    rechazado { FacturaItem.where(factura_id: @factura.id).delete_all }
  end

  test "lo que anota la anulación sí se escribe" do
    @factura.update!(estado: "anulada", anulada_at: Time.current, motivo_anulacion: "prueba")
    assert @factura.reload.anulada?
  end

  test "anulada va siempre con su fecha (CHECK)" do
    error = assert_raises(ActiveRecord::StatementInvalid) do
      Factura.transaction(requires_new: true) { @factura.update_columns(estado: "anulada") }
    end
    assert_kind_of PG::CheckViolation, error.cause
  end
end
