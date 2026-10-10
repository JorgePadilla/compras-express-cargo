require "test_helper"

# PR-F1.2 · `align_to` y la alineación al cargar un CAI.
class Fiscal::SequenceTest < ActiveSupport::TestCase
  setup do
    @sequence = Fiscal::Sequence.new
    @punto = puntos_de_emision(:sps)
  end

  def cargar(**atributos)
    AutorizacionSar.create!({ punto_de_emision: @punto, tipo_documento: "01", cai: "CAI-NUEVO",
                              fecha_limite_emision: Fiscal.hoy + 90 }.merge(atributos))
  end

  test "align_to sube el contador al rango que no arranca en 1, y nunca lo baja" do
    auth = Invoicehn::Authorization.new(cai: "X", range_start: "000-001-07-00000501",
                                        range_end: "000-001-07-00000600", limit_date: Fiscal.hoy + 30)
    assert_equal 500, @sequence.align_to(auth)
    assert_equal "000-001-07-00000501", @sequence.peek("000-001-07").to_s

    menor = Invoicehn::Authorization.new(cai: "Y", range_start: "000-001-07-00000101",
                                         range_end: "000-001-07-00000200", limit_date: Fiscal.hoy + 30)
    assert_equal 500, @sequence.align_to(menor)
  end

  test "el primer CAI de un punto que no arranca en 1 alinea el contador al cargarse" do
    cargar(punto_de_emision: puntos_de_emision(:tgu), rango_inicio: 1001, rango_fin: 2000)
    assert_equal "001-001-01-00001001", @sequence.peek("001-001-01").to_s
  end

  test "el CAI siguiente, cargado antes de que se acabe el actual, no saltea lo que le queda" do
    correlativos_fiscales(:sps_factura).update!(ultimo: 3000)
    cargar(rango_inicio: 5001, rango_fin: 6000)

    assert_equal 3000, @sequence.issued_count("000-001-01"), "los 3001–5000 del CAI actual se siguen usando"
  end

  test "si el actual ya no sirve, el siguiente alinea aunque haya un hueco" do
    correlativos_fiscales(:sps_factura).update!(ultimo: 5000)
    cargar(rango_inicio: 6001, rango_fin: 7000)

    assert_equal 6000, @sequence.issued_count("000-001-01")
  end

  test "un identificador de un punto que no existe o de un tipo que no se emite se rechaza" do
    assert_raises(Invoicehn::ValidationError) { @sequence.peek("009-009-01") }
    assert_raises(Invoicehn::ValidationError) { @sequence.allocate("000-001-02") { nil } }
  end
end
