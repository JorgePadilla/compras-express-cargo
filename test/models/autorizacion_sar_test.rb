require "test_helper"
require_relative "../support/con_app_host"

# PR-F1.1 · El CAI con su rango (Acuerdo 481-2017, Art. 59).
class AutorizacionSarTest < ActiveSupport::TestCase
  include ConAppHost

  setup do
    @sps = puntos_de_emision(:sps)
    @tgu = puntos_de_emision(:tgu)
    @ficticia = autorizaciones_sar(:ficticia)
  end

  def nueva(**atributos)
    AutorizacionSar.new({ punto_de_emision: @sps, tipo_documento: "01", cai: "CAI-NUEVO",
                          rango_inicio: 5001, rango_fin: 10_000,
                          fecha_limite_emision: Date.current + 365 }.merge(atributos))
  end

  # El modelo valida el solapamiento antes que la base; para probar el
  # `EXCLUDE` hay que saltearlo.
  def insertar_sin_validar(**atributos)
    nueva(**atributos).save!(validate: false)
  end

  test "la fixture es válida y su identificador es el del punto" do
    assert @ficticia.valid?, @ficticia.errors.full_messages.to_sentence
    assert_equal "000-001-01", @ficticia.identificador
    assert_equal 5000, @ficticia.capacidad
  end

  test "un rango contiguo al anterior sí entra" do
    assert nueva.save, nueva.errors.full_messages.to_sentence
  end

  # ── Solapamiento ──────────────────────────────────────────────────────────

  test "el modelo rechaza un rango que se pisa con otro del mismo punto y tipo" do
    [ [ 1, 5000 ], [ 5000, 6000 ], [ 100, 200 ], [ 4000, 9000 ] ].each do |inicio, fin|
      a = nueva(rango_inicio: inicio, rango_fin: fin)
      assert_not a.valid?, "#{inicio}-#{fin} se pisa con 1-5000"
      assert_match(/se pisa/, a.errors[:base].to_sentence)
    end
  end

  test "la base rechaza el solapamiento aunque se saltee el modelo" do
    error = assert_raises(ActiveRecord::StatementInvalid) { insertar_sin_validar(rango_inicio: 5000, rango_fin: 6000) }
    assert_kind_of PG::ExclusionViolation, error.cause
  end

  test "la base deja el mismo rango en otro tipo de documento o en otro punto" do
    assert_nothing_raised do
      insertar_sin_validar(tipo_documento: "06", rango_inicio: 1, rango_fin: 5000)
      insertar_sin_validar(punto_de_emision: @tgu, rango_inicio: 1, rango_fin: 5000)
    end
  end

  test "el modelo también deja el mismo rango en otro tipo o en otro punto" do
    assert nueva(tipo_documento: "06", rango_inicio: 1, rango_fin: 5000).valid?
    assert nueva(punto_de_emision: @tgu, rango_inicio: 1, rango_fin: 5000).valid?
  end

  # ── Bordes del rango ──────────────────────────────────────────────────────

  test "el rango va de 1 a 99999999, inicio antes que fin" do
    assert nueva(punto_de_emision: @tgu, rango_inicio: 1, rango_fin: 1).valid?
    assert nueva(punto_de_emision: @tgu, rango_inicio: 99_999_999, rango_fin: 99_999_999).valid?

    assert_not nueva(punto_de_emision: @tgu, rango_inicio: 0, rango_fin: 10).valid?
    assert_not nueva(punto_de_emision: @tgu, rango_inicio: 1, rango_fin: 100_000_000).valid?
    assert_not nueva(punto_de_emision: @tgu, rango_inicio: 10, rango_fin: 9).valid?
    assert_not nueva(punto_de_emision: @tgu, rango_inicio: 1.5, rango_fin: 9).valid?
  end

  test "la base rechaza los bordes malos aunque se saltee el modelo" do
    [ [ 0, 10 ], [ 1, 100_000_000 ], [ 10, 9 ] ].each do |inicio, fin|
      error = assert_raises(ActiveRecord::StatementInvalid, "#{inicio}-#{fin}") do
        insertar_sin_validar(punto_de_emision: @tgu, rango_inicio: inicio, rango_fin: fin)
      end
      assert_kind_of PG::CheckViolation, error.cause
    end
  end

  test "solo los tipos que se emiten: 01, 06 y 07" do
    assert_not nueva(tipo_documento: "02").valid?
    error = assert_raises(ActiveRecord::StatementInvalid) { insertar_sin_validar(tipo_documento: "05") }
    assert_kind_of PG::CheckViolation, error.cause
  end

  test "el CAI es obligatorio y se guarda tal cual, sin espacios en las puntas" do
    assert_not nueva(cai: "  ").valid?
    assert_equal "35a2E0-5A6F5C", nueva(cai: "  35a2E0-5A6F5C \n").cai
  end

  # ── Lo ya emitido ─────────────────────────────────────────────────────────

  test "un rango nuevo arranca arriba del último número emitido" do
    correlativos_fiscales(:sps_factura).update!(ultimo: 6000)

    baja = nueva(rango_inicio: 5001, rango_fin: 10_000)
    assert_not baja.valid?
    assert_match(/6000/, baja.errors[:rango_inicio].to_sentence)

    assert nueva(rango_inicio: 6001, rango_fin: 10_000).valid?
  end

  test "sin correlativo todavía, cualquier rango desde 1 entra" do
    assert nueva(punto_de_emision: @tgu, rango_inicio: 1).valid?
  end

  test "sin documentos emitidos se edita y se borra" do
    assert_not @ficticia.documentos_emitidos?
    assert @ficticia.update(fecha_limite_emision: Date.current + 200)
    assert @ficticia.destroy
  end

  test "con documentos emitidos no se edita" do
    correlativos_fiscales(:sps_factura).update!(ultimo: 1)
    assert @ficticia.documentos_emitidos?

    assert_not @ficticia.update(fecha_limite_emision: Date.current + 200)
    assert_match(/Ya se emitieron/, @ficticia.errors[:base].to_sentence)
  end

  test "con documentos emitidos no se borra" do
    correlativos_fiscales(:sps_factura).update!(ultimo: 1)

    assert_not @ficticia.destroy
    assert_match(/no se puede borrar/, @ficticia.errors[:base].to_sentence)
    assert AutorizacionSar.exists?(@ficticia.id)
  end

  test "la autorización siguiente sigue editable mientras no se llegue a su rango" do
    siguiente = nueva.tap(&:save!)
    correlativos_fiscales(:sps_factura).update!(ultimo: 5000)

    assert @ficticia.documentos_emitidos?
    assert_not siguiente.documentos_emitidos?
    assert siguiente.update(cai: "CAI-CORREGIDO")
  end

  # ── Ficticia ──────────────────────────────────────────────────────────────

  test "una ficticia no se acepta en producción" do
    en_produccion do
      a = nueva(ficticia: true)
      assert_not a.valid?
      assert a.errors[:ficticia].any?
      assert nueva(ficticia: false).valid?
    end
  end

  test "en staging la ficticia entra" do
    con_app_host("cec-staging.onrender.com") { assert nueva(ficticia: true).valid? }
    con_app_host(nil) { assert nueva(ficticia: true).valid? }
  end

  test "vencida al día siguiente de la fecha límite, no ese día" do
    @ficticia.fecha_limite_emision = Date.new(2026, 10, 10)
    assert_not @ficticia.vencida?(Date.new(2026, 10, 10))
    assert @ficticia.vencida?(Date.new(2026, 10, 11))
  end
end
