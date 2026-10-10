require "test_helper"

# PR-F1.1 · El libro fiscal solo se agrega (D2 de FISCAL.md). La base lo
# garantiza con un trigger; el modelo, con `readonly?`.
class AsientoFiscalTest < ActiveSupport::TestCase
  setup do
    @asiento = AsientoFiscal.create!(
      evento: "emision", tipo_documento: "01", numero: "000-001-01-00000001",
      punto_de_emision: puntos_de_emision(:sps), documento: ventas(:pendiente_juan),
      fecha_emision: Fiscal.hoy, cai: autorizaciones_sar(:ficticia).cai,
      cliente_nombre: "Juan Pérez", moneda: "LPS",
      subtotal: 100, descuento: 0, isv: 15, total: 115, estado: "emitida",
      payload: { "correlative" => "000-001-01-00000001" }
    )
  end

  test "se agrega, y la base le pone la hora del registro" do
    assert @asiento.persisted?
    assert_not_nil @asiento.reload.registrado_at
  end

  test "el modelo no deja tocarlo una vez creado" do
    assert @asiento.readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { @asiento.update!(total: 1) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { @asiento.destroy }
  end

  test "el trigger rechaza UPDATE aunque se saltee el modelo" do
    error = assert_raises(ActiveRecord::StatementInvalid) do
      AsientoFiscal.where(id: @asiento.id).update_all(total: 1)
    end
    assert_match(/solo admite INSERT \(UPDATE rechazado\)/, error.message)
  end

  test "el trigger rechaza DELETE aunque se saltee el modelo" do
    # En un savepoint: el error deja la transacción abortada, y después se
    # pregunta si la fila sigue.
    error = assert_raises(ActiveRecord::StatementInvalid) do
      AsientoFiscal.transaction(requires_new: true) { AsientoFiscal.where(id: @asiento.id).delete_all }
    end
    assert_match(/solo admite INSERT \(DELETE rechazado\)/, error.message)
    assert AsientoFiscal.exists?(@asiento.id)
  end

  test "una anulación es otro asiento, y el mismo evento no se repite para un número" do
    AsientoFiscal.create!(@asiento.attributes.except("id", "registrado_at").merge("evento" => "anulacion", "estado" => "anulada"))
    assert_equal 2, AsientoFiscal.where(numero: @asiento.numero).count

    repetido = AsientoFiscal.new(@asiento.attributes.except("id", "registrado_at"))
    assert_raises(ActiveRecord::RecordNotUnique) { repetido.save! }
  end

  test "el número es EEE-PPP-TT-NNNNNNNN y el evento, emisión o anulación" do
    malo = AsientoFiscal.new(@asiento.attributes.except("id", "registrado_at").merge("numero" => "1", "evento" => "edicion"))
    assert_not malo.valid?
    assert malo.errors[:numero].any?
    assert malo.errors[:evento].any?
  end

  # Es como se limpia en los tests que corren sin transacción (F1.2).
  test "TRUNCATE no pasa por el trigger" do
    AsientoFiscal.connection.execute("TRUNCATE asientos_fiscales")
    assert_equal 0, AsientoFiscal.count
  end
end
