require "test_helper"
require_relative "../../support/con_quien_factura"

# PR-F2.2a · Dos personas facturando a la vez, cada una en su conexión.
#
# Sin transacción de test (dos conexiones no ven lo que la otra no confirmó), así
# que lo que se crea se borra a mano: la factura y sus líneas no se dejan borrar
# (trigger), y para limpiar se apaga el trigger un momento.
class Fiscal::EmitirFacturaConcurrenciaTest < ActiveSupport::TestCase
  include SinTransaccionDeTest
  include ConQuienFactura

  setup do
    @cajero = quien_factura
    @supervisor = quien_factura(users(:supervisor_prefactura))
  end

  teardown do
    c = ActiveRecord::Base.connection
    c.execute("ALTER TABLE facturas DISABLE TRIGGER facturas_fiscal_inmutable")
    c.execute("ALTER TABLE factura_items DISABLE TRIGGER factura_items_inmutables")
    PreFactura.where.not(factura_id: nil).update_all(factura_id: nil)
    FacturaItem.delete_all
    Factura.delete_all
    c.execute("ALTER TABLE facturas ENABLE TRIGGER facturas_fiscal_inmutable")
    c.execute("ALTER TABLE factura_items ENABLE TRIGGER factura_items_inmutables")
    c.execute("TRUNCATE asientos_fiscales, documentos_fiscales")
    PaperTrail::Version.where(item_type: %w[Factura FacturaItem DocumentoFiscal PreFactura]).delete_all
  end

  # Corre en su conexión y devuelve la factura o el error, sin tirar.
  def en_su_conexion(pre_factura, por)
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        Fiscal::EmitirFactura.new(pre_facturas: [ pre_factura ], por: por).call
      rescue StandardError => e
        e
      end
    end
  end

  test "dos pre-facturas facturadas a la vez en el mismo punto salen con números consecutivos" do
    hilos = [ en_su_conexion(pre_facturas(:pendiente_maria), @cajero),
              en_su_conexion(pre_facturas(:borrador_juan), @supervisor) ]
    facturas = hilos.map(&:value)

    assert(facturas.all?(Factura), facturas.inspect)
    assert_equal %w[000-001-01-00000001 000-001-01-00000002], facturas.map(&:numero).sort
    assert_equal 2, Fiscal::Sequence.new.issued_count("000-001-01")
    assert_equal 2, AsientoFiscal.count
  end

  test "la misma pre-factura facturada por dos a la vez: una factura, y al otro se le dice por qué" do
    pf = pre_facturas(:pendiente_maria)
    resultados = [ en_su_conexion(pf, @cajero), en_su_conexion(pf, @supervisor) ].map(&:value)

    assert_equal 1, resultados.count { |r| r.is_a?(Factura) }, resultados.inspect
    assert_equal 1, resultados.count { |r| r.is_a?(Fiscal::PreFacturasNoFacturables) }, resultados.inspect
    assert_equal 1, Factura.count
    assert_equal 1, Fiscal::Sequence.new.issued_count("000-001-01"), "el segundo no consumió número"
  end
end
