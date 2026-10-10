require "test_helper"
require_relative "../../support/con_quien_factura"

# PR-F2.2a · Anular una factura SAR (Art. 41). Jorge (Q6): PIN de supervisor y
# motivo, cuatro ojos; con pagos no se anula.
class Fiscal::AnularFacturaTest < ActiveSupport::TestCase
  include ConQuienFactura

  setup do
    @cajero = quien_factura
    @supervisor = users(:supervisor_prefactura)
    @supervisor.update!(pin: "1234")
    @pf = pre_facturas(:pendiente_maria)
    @factura = Fiscal::EmitirFactura.new(pre_facturas: [ @pf ], por: @cajero).call
  end

  def anular(autorizado_por: @supervisor, pin: "1234", motivo: "RTN equivocado", por: @cajero)
    Fiscal::AnularFactura.new(factura: @factura, por: por, autorizado_por: autorizado_por, pin: pin,
                              motivo: motivo).call
  end

  test "anula: factura y documento ANULADOS, asiento de anulación, bitácora, y la pre-factura se suelta" do
    anulada = anular

    assert anulada.anulada?
    assert_equal "RTN equivocado", anulada.motivo_anulacion
    assert_not_nil anulada.anulada_at
    assert_predicate anulada.to_invoicehn, :annulled?
    assert_equal %w[emision anulacion], AsientoFiscal.where(numero: anulada.numero).order(:id).pluck(:evento)

    autorizacion = Autorizacion.find_by!(documento: anulada, accion: "anular_factura")
    assert_equal @supervisor, autorizacion.autorizado_por
    assert_equal "Factura anulada", autorizacion.accion_label

    @pf.reload
    assert_nil @pf.factura_id
    assert_equal "pendiente", @pf.estado
  end

  test "el número anulado no se vuelve a usar: la siguiente factura sigue la serie" do
    anular
    nueva = Fiscal::EmitirFactura.new(pre_facturas: [ @pf.reload ], por: @cajero).call
    assert_equal "000-001-01-00000002", nueva.numero
  end

  test "sin motivo, con PIN malo, o autorizada por quien la emitió, no se anula" do
    assert_raises(Fiscal::AnulacionRechazada) { anular(motivo: " ") }
    assert_raises(Fiscal::AnulacionRechazada) { anular(pin: "9999") }

    @cajero.update!(pin: "4321")
    error = assert_raises(Fiscal::AnulacionRechazada) { anular(autorizado_por: @cajero, pin: "4321") }
    assert_match(/no tiene PIN de autorizacion|no puede ser quien creo la factura/, error.message)

    assert @factura.reload.emitida?
    assert_equal 1, AsientoFiscal.count
  end

  test "un supervisor que la emitió tampoco la autoriza él mismo (cuatro ojos)" do
    @factura.update_columns(creado_por_id: @supervisor.id)
    error = assert_raises(Fiscal::AnulacionRechazada) { anular(por: @supervisor) }
    assert_match(/no puede ser quien creo la factura/, error.message)
  end

  test "con pagos completados no se anula: va nota de crédito" do
    @factura.define_singleton_method(:pagos_completados?) { true }
    error = assert_raises(Fiscal::AnulacionRechazada) { anular }
    assert_match(/nota de crédito/, error.message)
    assert @factura.reload.emitida?
  end

  test "dos veces no" do
    anular
    @factura.reload
    assert_raises(Fiscal::AnulacionRechazada) { anular }
  end
end
