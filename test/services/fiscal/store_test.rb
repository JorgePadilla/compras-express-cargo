require "test_helper"
require_relative "../../support/con_app_host"
require "invoicehn/testing"

# PR-F1.2 · Lo que la app le agrega al contrato de la gema: cuál CAI usa, qué
# ignora en producción, por qué se niega, y el borrador.
class Fiscal::StoreTest < ActiveSupport::TestCase
  include ConAppHost

  setup do
    @punto = puntos_de_emision(:sps)
    @store = Fiscal::Store.new(punto: @punto)
    @ficticia = autorizaciones_sar(:ficticia)
    @linea = Invoicehn::LineItem.new(description: "Flete CER", quantity: 1,
                                     unit_price: Invoicehn::Money.new("100.00"), treatment: :gravado_15)
  end

  def emitir(store: @store, identifier: "000-001-01", customer: Invoicehn::Customer::ConsumidorFinal.new)
    Invoicehn::Issuance.new(store: store, sequence: Fiscal::Sequence.new, ledger: Fiscal::Ledger.new)
                       .issue(customer: customer, line_items: [ @linea ], identifier: identifier)
  end

  def cai_siguiente(**atributos)
    AutorizacionSar.create!({ punto_de_emision: @punto, tipo_documento: "01", cai: "CAI-SIGUIENTE",
                              rango_inicio: 5001, rango_fin: 6000,
                              fecha_limite_emision: Fiscal.hoy + 60 }.merge(atributos))
  end

  test "entre dos CAI sucesivos elige el que cubre el número que sigue" do
    cai_siguiente
    assert_equal @ficticia.cai, @store.active_authorization("000-001-01", next_sequence: 5000).cai
    assert_equal "CAI-SIGUIENTE", @store.active_authorization("000-001-01", next_sequence: 5001).cai
  end

  test "al terminarse un rango, la emisión sigue en el siguiente sin saltar números" do
    correlativos_fiscales(:sps_factura).update!(ultimo: 4999)
    cai_siguiente

    assert_equal "000-001-01-00005000", emitir.correlative.to_s
    segunda = emitir
    assert_equal "000-001-01-00005001", segunda.correlative.to_s
    assert_equal "CAI-SIGUIENTE", segunda.authorization.cai
  end

  test "en producción la ficticia no cuenta, y sin otra no se emite" do
    en_produccion do
      assert_empty @store.authorizations_for("000-001-01")
      assert_raises(Invoicehn::NoAuthorization) { emitir }
    end
    assert_equal [ @ficticia.cai ], @store.authorizations_for("000-001-01").map(&:cai)
  end

  # La gema filtra antes las vencidas y las agotadas, así que la emisión dice
  # `NoAuthorization`; los motivos puntuales los da la autorización misma.
  test "vencida: no se emite, y la autorización dice por qué" do
    @ficticia.update_columns(fecha_limite_emision: Fiscal.hoy - 1)

    assert_raises(Invoicehn::NoAuthorization) { emitir }
    assert_raises(Invoicehn::AuthorizationExpired) do
      @ficticia.to_invoicehn.assert_usable!("000-001-01-00000001", on: Fiscal.hoy)
    end
    assert_equal 0, Fiscal::Sequence.new.issued_count("000-001-01"), "el número no se quemó"
  end

  test "agotada: no se emite, y la autorización dice por qué" do
    correlativos_fiscales(:sps_factura).update!(ultimo: 5000)

    assert_raises(Invoicehn::NoAuthorization) { emitir }
    assert_raises(Invoicehn::RangeExhausted) do
      @ficticia.to_invoicehn.assert_usable!("000-001-01-00005001", on: Fiscal.hoy)
    end
    assert_equal 5000, Fiscal::Sequence.new.issued_count("000-001-01")
  end

  test "un número de otro punto no se guarda con este emisor" do
    otra = Fiscal::Store.new(punto: puntos_de_emision(:tgu))
    AutorizacionSar.create!(punto_de_emision: puntos_de_emision(:tgu), tipo_documento: "01", cai: "CAI-TGU",
                            rango_inicio: 1, rango_fin: 10, fecha_limite_emision: Fiscal.hoy + 30)
    assert_raises(Invoicehn::ValidationError) { emitir(store: otra, identifier: "000-001-01") }
    assert_equal 0, DocumentoFiscal.count
  end

  test "el borrador queda como documentable, se estampa y se guarda" do
    borrador = ventas(:pendiente_juan)
    def borrador.estampar_documento_fiscal(invoice) = self.notas = "Factura #{invoice.correlative}"

    factura = emitir(store: Fiscal::Store.new(punto: @punto, borrador: borrador))

    documento = DocumentoFiscal.find_by!(numero: factura.correlative.to_s)
    assert_equal borrador, documento.documentable
    assert_equal "Factura 000-001-01-00000001", borrador.reload.notas
    assert_equal documento, AsientoFiscal.find_by!(numero: documento.numero).documento
  end

  test "si el libro rechaza la anulación, la emitida vuelve con su borrador" do
    borrador = ventas(:pendiente_juan)
    factura = emitir(store: Fiscal::Store.new(punto: @punto, borrador: borrador))

    rechaza = Invoicehn::Testing::RefusingLedger.new
    issuance = Invoicehn::Issuance.new(store: Fiscal::Store.new(punto: @punto), sequence: Fiscal::Sequence.new,
                                       ledger: rechaza)
    assert_raises(Invoicehn::Testing::RefusingLedger::Refused) { issuance.annul(factura.correlative, reason: "Error") }

    documento = DocumentoFiscal.find_by!(numero: factura.correlative.to_s)
    assert_equal "emitida", documento.estado
    assert_equal borrador, documento.documentable
  end

  test "anular reemplaza el documento y agrega un asiento, sin tocar el de la emisión" do
    factura = emitir
    Fiscal.issuance(punto: @punto).annul(factura.correlative, reason: "Cliente equivocado")

    assert_predicate @store.find(factura.correlative), :annulled?
    assert_equal %w[emision anulacion], AsientoFiscal.where(numero: factura.correlative.to_s).order(:id).pluck(:evento)
  end

  test "all devuelve en orden cronológico" do
    tres = 3.times.map { emitir.correlative.to_s }
    assert_equal tres, @store.all.map { |d| d.correlative.to_s }
    assert_empty @store.all(from: Fiscal.hoy + 1)
  end

  test "add_authorization pasa por las reglas del modelo" do
    nueva = Invoicehn::Authorization.new(cai: "CAI-AGREGADA", range_start: "000-001-01-00005001",
                                         range_end: "000-001-01-00006000", limit_date: Fiscal.hoy + 90)
    @store.add_authorization(nueva)
    assert AutorizacionSar.exists?(cai: "CAI-AGREGADA")

    pisada = Invoicehn::Authorization.new(cai: "CAI-PISADA", range_start: "000-001-01-00000100",
                                          range_end: "000-001-01-00000200", limit_date: Fiscal.hoy + 90)
    assert_raises(Invoicehn::ValidationError) { @store.add_authorization(pisada) }
  end
end
