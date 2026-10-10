require "test_helper"

# PR-F1.2 · El correlativo con hilos de verdad, cada uno en su conexión.
#
# La SAR no acepta huecos ni repetidos (Art. 10 num. 7 lit. d). Lo que lo
# sostiene es el `SELECT … FOR UPDATE` de `Fiscal::Sequence#allocate`: con dos
# emitiendo a la vez en el mismo punto y tipo, el segundo espera al primero.
# Eso solo se ve con dos conexiones, y por eso sin transacción de test.
class Fiscal::SequenceConcurrenciaTest < ActiveSupport::TestCase
  include SinTransaccionDeTest

  HILOS = 8
  POR_HILO = 25
  IDENTIFICADOR = "000-001-01".freeze

  setup do
    @sequence = Fiscal::Sequence.new
  end

  # Las fixtures se recargan solas antes del próximo test (el correlativo
  # vuelve a 0); esto es lo que no tiene fixtures.
  teardown do
    ActiveRecord::Base.connection.execute("TRUNCATE asientos_fiscales, documentos_fiscales")
    PaperTrail::Version.where(item_type: "DocumentoFiscal").delete_all
  end

  test "#{HILOS} hilos × #{POR_HILO} números: exactamente 1..#{HILOS * POR_HILO}, sin huecos ni repetidos" do
    emitidos = Queue.new

    hilos = Array.new(HILOS) do
      Thread.new do
        POR_HILO.times do
          # Una conexión por número y no por hilo: el pool es de 5, y así los
          # 8 hilos se la turnan sin quedarse esperando el checkout.
          ActiveRecord::Base.connection_pool.with_connection do
            @sequence.allocate(IDENTIFICADOR) { |correlativo| emitidos << correlativo.sequence }
          end
        end
      end
    end
    hilos.each(&:join)

    numeros = Array.new(emitidos.size) { emitidos.pop }
    assert_equal (1..HILOS * POR_HILO).to_a, numeros.sort
    assert_equal HILOS * POR_HILO, @sequence.issued_count(IDENTIFICADOR)
  end

  test "con emisiones completas en paralelo, los documentos quedan sin huecos y cada uno con su asiento" do
    punto = puntos_de_emision(:sps)
    linea = Invoicehn::LineItem.new(description: "Flete", quantity: 1, unit_price: Invoicehn::Money.new("100.00"),
                                    treatment: :gravado_15)

    hilos = Array.new(4) do
      Thread.new do
        5.times do
          ActiveRecord::Base.connection_pool.with_connection do
            Fiscal.issuance(punto: punto).issue(customer: Invoicehn::Customer::ConsumidorFinal.new,
                                                line_items: [ linea ], identifier: IDENTIFICADOR)
          end
        end
      end
    end
    hilos.each(&:join)

    esperados = (1..20).map { |n| format("000-001-01-%08d", n) }
    assert_equal esperados, DocumentoFiscal.order(:numero).pluck(:numero)
    assert_equal esperados, AsientoFiscal.where(evento: "emision").order(:numero).pluck(:numero)
  end

  test "si el bloque tira, el último no se mueve y el número se vuelve a dar" do
    @sequence.allocate(IDENTIFICADOR) { :primero }
    assert_equal 1, @sequence.issued_count(IDENTIFICADOR)

    assert_raises(RuntimeError) do
      @sequence.allocate(IDENTIFICADOR) { |c| raise "falla con #{c}" }
    end
    assert_equal 1, @sequence.issued_count(IDENTIFICADOR)

    assert_equal 2, @sequence.allocate(IDENTIFICADOR, &:sequence)
  end
end
