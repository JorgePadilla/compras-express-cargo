require "test_helper"

# PR-F1.2 · El libro en Postgres devuelve lo mismo que el de la gema: las
# mismas llaves, los mismos valores. Es lo que lee la exportación a la SAR.
class Fiscal::LedgerTest < ActiveSupport::TestCase
  setup do
    @punto = puntos_de_emision(:sps)
    lineas = [ Invoicehn::LineItem.new(description: "Flete", quantity: 3, unit_price: Invoicehn::Money.new("93.98"),
                                       treatment: :gravado_15, discount: Invoicehn::Money.new("10.00")) ]
    cliente = Invoicehn::Customer::Taxpayer.new(name: "Juan Pérez López", rtn: "08011985123456")
    @factura = Fiscal.issuance(punto: @punto).issue(customer: cliente, line_items: lineas, identifier: "000-001-01")
  end

  def libro_de_la_gema(*registros)
    Dir.mktmpdir do |dir|
      gema = Invoicehn::Ledger::JsonlLedger.new(Invoicehn::Config.new(home: dir))
      registros.each { |documento, evento| gema.record(documento, event: evento) }
      gema.entries.map { |e| e.except("recorded_at") }
    end
  end

  test "las entradas son las del JsonlLedger, emisión y anulación" do
    anulada = Fiscal.issuance(punto: @punto).annul(@factura.correlative, reason: "Prueba")

    nuestras = Fiscal::Ledger.new.entries
    assert_equal libro_de_la_gema([ @factura, :emision ], [ anulada, :anulacion ]),
                 nuestras.map { |e| e.except("recorded_at") }
    assert(nuestras.all? { |e| e["recorded_at"].match?(/\A\d{4}-\d\d-\d\dT/) })
  end

  test "una nota guarda la referencia a su factura" do
    AutorizacionSar.create!(punto_de_emision: @punto, tipo_documento: "06", cai: "CAI-NC", rango_inicio: 1,
                            rango_fin: 100, fecha_limite_emision: Fiscal.hoy + 30)
    nota = Fiscal.issuance(punto: @punto).issue_credit_note(
      reference: @factura.correlative.to_s, motivo: "Descuento posterior", customer: @factura.customer,
      line_items: [ Invoicehn::LineItem.new(description: "Descuento", quantity: 1,
                                            unit_price: Invoicehn::Money.new("10.00"), treatment: :gravado_15) ]
    )

    asiento = AsientoFiscal.find_by!(numero: nota.correlative.to_s)
    assert_equal @factura.correlative.to_s, asiento.referencia
    assert_equal libro_de_la_gema([ @factura, :emision ], [ nota, :emision ]),
                 Fiscal::Ledger.new.entries.map { |e| e.except("recorded_at") }
  end

  test "filtra por fecha de emisión" do
    assert_equal 1, Fiscal::Ledger.new.entries(from: Fiscal.hoy, to: Fiscal.hoy).size
    assert_empty Fiscal::Ledger.new.entries(from: Fiscal.hoy + 1)
  end

  test "el asiento sigue siendo solo para agregar" do
    assert_raises(ActiveRecord::StatementInvalid) do
      AsientoFiscal.transaction(requires_new: true) { AsientoFiscal.update_all(total: 0) }
    end
  end
end
