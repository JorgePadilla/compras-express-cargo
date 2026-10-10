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

  # El trigger de columnas deja escribir lo que anota la anulación; lo que la
  # respalda lo mira `facturas_respaldo_fiscal` al confirmar (abajo).
  test "lo que anota la anulación sí se escribe" do
    @factura.update!(estado: "anulada", anulada_at: Time.current, motivo_anulacion: "prueba")
    assert @factura.reload.anulada?
  end

  # ── QA de PR-F2.2a · El respaldo fiscal, al confirmar ─────────────────
  #
  # `facturas_respaldo_fiscal` es DEFERRABLE INITIALLY DEFERRED: corre al
  # COMMIT, que un test transaccional no hace. `SET CONSTRAINTS ALL IMMEDIATE`
  # lo dispara en el momento.
  def al_confirmar(&)
    Factura.transaction(requires_new: true) do
      yield
      Factura.connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
    end
  end

  def respaldo_rechazado(&)
    error = assert_raises(ActiveRecord::StatementInvalid) { al_confirmar(&) }
    assert_kind_of PG::RestrictViolation, error.cause
    error
  end

  test "la emisión de verdad tiene su respaldo" do
    assert_nothing_raised do
      al_confirmar { Fiscal::EmitirFactura.new(pre_facturas: [ pre_facturas(:borrador_juan) ], por: quien_factura).call }
    end
  end

  test "una anulación forjada con UPDATE no se confirma: ni documento anulado ni asiento" do
    error = respaldo_rechazado do
      Factura.connection.execute("UPDATE facturas SET estado = 'anulada', anulada_at = now(), " \
                                 "motivo_anulacion = 'forjada' WHERE id = #{@factura.id}")
    end
    assert_match "no tiene su documento fiscal en estado anulada", error.message
    assert @factura.reload.emitida?
  end

  test "anulada en el libro, no se des-anula, aunque se toque también el documento" do
    supervisor = users(:supervisor_prefactura)
    supervisor.update!(pin: "1234")
    Fiscal::AnularFactura.new(factura: @factura, por: quien_factura, autorizado_por: supervisor, pin: "1234",
                              motivo: "RTN equivocado").call
    al_confirmar { nil }

    error = respaldo_rechazado do
      DocumentoFiscal.where(numero: @factura.numero).update_all(estado: "emitida")
      Factura.connection.execute("UPDATE facturas SET estado = 'emitida', anulada_at = NULL WHERE id = #{@factura.id}")
    end
    assert_match "el libro dice otra cosa", error.message
    assert @factura.reload.anulada?
  end

  test "anulada va siempre con su fecha (CHECK)" do
    error = assert_raises(ActiveRecord::StatementInvalid) do
      Factura.transaction(requires_new: true) { @factura.update_columns(estado: "anulada") }
    end
    assert_kind_of PG::CheckViolation, error.cause
  end
end
