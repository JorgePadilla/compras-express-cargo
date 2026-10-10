require "test_helper"
require_relative "../../support/con_quien_factura"

# PR-F2.2a · La emisión de la factura SAR, dormida (nada de la interfaz la
# llama). Fixtures: `pendiente_maria` (L 25.00 + ISV = 28.75), el punto de SPS
# con su CAI ficticio 1–5000, y la Empresa de prueba completa.
class Fiscal::EmitirFacturaTest < ActiveSupport::TestCase
  include ConQuienFactura

  setup do
    @cajero = quien_factura
    @pf = pre_facturas(:pendiente_maria)
  end

  def emitir(pre_facturas = [ @pf ], por: @cajero)
    Fiscal::EmitirFactura.new(pre_facturas: pre_facturas, por: por).call
  end

  def ultimo = Fiscal::Sequence.new.issued_count("000-001-01")

  test "emite con el primer número del punto, lo fiscal estampado y las líneas de la pre-factura" do
    factura = emitir

    assert_equal "000-001-01-00000001", factura.numero
    assert_equal "emitida", factura.estado
    assert_equal puntos_de_emision(:sps), factura.punto_de_emision
    assert_equal autorizaciones_sar(:ficticia).cai, factura.cai
    assert_equal "000-001-01-00000001", factura.rango_inicio
    assert_equal "000-001-01-00005000", factura.rango_fin
    assert_equal Fiscal.hoy, factura.fecha_emision
    assert_equal [ BigDecimal("25.00"), BigDecimal("3.75"), BigDecimal("28.75") ],
                 [ factura.subtotal, factura.impuesto, factura.total ]
    assert_equal @pf.total, factura.total
    assert_equal [ pre_factura_items(:pendiente_maria_item1) ], factura.factura_items.map(&:pre_factura_item)
    assert_equal @cajero, factura.creado_por

    assert_equal factura, factura.documento_fiscal.documentable
    assert_equal factura.numero, AsientoFiscal.find_by!(evento: "emision").numero
    assert_equal 1, ultimo

    @pf.reload
    assert_equal "facturado", @pf.estado
    assert_equal factura.id, @pf.factura_id
  end

  test "dos emisiones seguidas en el mismo punto dan números consecutivos" do
    primera = emitir
    segunda = emitir([ pre_facturas(:borrador_juan) ])
    assert_equal %w[000-001-01-00000001 000-001-01-00000002], [ primera.numero, segunda.numero ]
  end

  test "el cliente sin RTN sale consumidor final; con RTN, contribuyente" do
    assert_nil emitir.cliente_rtn

    clientes(:juan).update_columns(rtn: "08011985123456")
    factura = emitir([ pre_facturas(:borrador_juan) ])
    assert_equal "08011985123456", factura.cliente_rtn
    assert factura.to_invoicehn.customer.taxpayer?
  end

  test "en dólares lleva la tasa con la fecha de hoy (Art. 11)" do
    @pf.update_columns(moneda: "USD", tasa_cambio_aplicada: BigDecimal("27.10"))
    factura = emitir

    assert_equal "USD", factura.moneda
    assert_equal BigDecimal("27.10"), factura.tasa_cambio
    tasa = factura.to_invoicehn.exchange_rate
    assert_equal Fiscal.hoy, tasa.date
    assert_equal Fiscal::EmitirFactura::FUENTE_DE_LA_TASA, tasa.source
  end

  # ── Lo que frena antes de pedir número ────────────────────────────────

  test "quien factura sin sucursal, o con una sin punto, no factura" do
    assert_raises(Fiscal::SinPuntoDeEmision) { emitir(por: quien_factura(sucursal: nil)) }
    assert_raises(Fiscal::SinPuntoDeEmision) { emitir(por: quien_factura(sucursal: sucursales(:miami))) }

    puntos_de_emision(:sps).update!(activo: false)
    assert_raises(Fiscal::SinPuntoDeEmision) { emitir(por: quien_factura) }
    assert_equal 0, ultimo
  end

  test "una línea sin concepto no se factura (Art. 11)" do
    pre_factura_items(:pendiente_maria_item1).update_columns(concepto: "  ")
    error = assert_raises(Fiscal::PreFacturasNoFacturables) { emitir }
    assert_match(/sin concepto/, error.message)
    assert_equal 0, ultimo
  end

  test "una pre-factura ya facturada, anulada o con factura no se vuelve a facturar" do
    emitir
    assert_raises(Fiscal::PreFacturasNoFacturables) { emitir }

    pre_facturas(:borrador_juan).update_columns(estado: "anulado")
    assert_raises(Fiscal::PreFacturasNoFacturables) { emitir([ pre_facturas(:borrador_juan) ]) }
    assert_equal 1, ultimo
  end

  test "pre-facturas de clientes distintos no van en la misma factura" do
    assert_raises(Fiscal::PreFacturasNoFacturables) { emitir([ @pf, pre_facturas(:borrador_juan) ]) }
  end

  # ── Lo que frena adentro del correlativo: no deja nada ────────────────

  test "si los totales no cuadran, no hay factura, el número no se consume y no hay asiento" do
    @pf.update_columns(total: BigDecimal("28.74"))

    assert_raises(Fiscal::TotalesNoCuadran) { emitir }
    assert_nada_quedo
  end

  test "una excepción después de pedir número no deja factura, ni número, ni asiento" do
    Fiscal::Ledger.class_eval do
      alias_method :record_original, :record
      define_method(:record) { |*| raise "el libro se cayó" }
    end
    assert_raises(RuntimeError) { emitir }
    assert_nada_quedo
  ensure
    Fiscal::Ledger.class_eval do
      alias_method :record, :record_original
      remove_method :record_original
    end
  end

  test "sin CAI vigente no factura, y no consume número" do
    autorizaciones_sar(:ficticia).update_columns(fecha_limite_emision: Fiscal.hoy - 1)
    assert_raises(Invoicehn::NoAuthorization) { emitir }
    assert_nada_quedo
  end

# QA de PR-F2.2a · Art. 11 num. 2 (Q8 de FISCAL.md): a un consumidor final,
# pasando L 10,000.00 hay que consignar su identidad. La gema lo rechaza
# adentro del correlativo: no queda nada, y la pre-factura sigue pendiente.
# Con la identidad del cliente, sale.
test "consumidor final por más de L 10,000 sin identidad no se factura, y no consume número" do
  item = @pf.pre_factura_items.first
  item.update_columns(subtotal: 9500, peso_cobrar: nil, precio_libra: nil, minimo_aplicado: true)
  @pf.reload.save!
  assert_operator @pf.total, :>, 10_000
  @pf.cliente.update_columns(rtn: nil, identidad: nil)

  error = assert_raises(Invoicehn::ComplianceError) { emitir }
  assert_match "Art. 11 num. 2", error.message
  assert_nada_quedo

  @pf.cliente.update_columns(identidad: "0801199012345")
  factura = emitir
  assert_equal "000-001-01-00000001", factura.numero
  assert_match "0801199012345", factura.cliente_identificacion
end

  private

  def assert_nada_quedo
    assert_equal 0, Factura.count, "quedó una factura"
    assert_equal 0, DocumentoFiscal.count, "quedó un documento fiscal"
    assert_equal 0, AsientoFiscal.count, "quedó un asiento"
    assert_equal 0, ultimo, "se consumió un número"
    assert_nil @pf.reload.factura_id
    assert_equal "pendiente", @pf.estado
  end
end
