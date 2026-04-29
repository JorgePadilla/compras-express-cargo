require "test_helper"

class WarehouseReceiptTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
  end

  def build_wr(attrs = {})
    WarehouseReceipt.new({
      receipt_number: "RM0002026000001",
      issued_on: Date.current,
      consignee: @cliente
    }.merge(attrs))
  end

  test "valid con campos requeridos (incluye consignee)" do
    assert build_wr(status: "draft").valid?
  end

  test "consignee es requerido — sin consignee no es válido" do
    wr = WarehouseReceipt.new(receipt_number: "RM0002026000999", issued_on: Date.current)
    assert_not wr.valid?
    assert wr.errors[:consignee].any?, "esperaba error de presence en consignee"
  end

  test "receipt_number es requerido y único case-insensitive" do
    WarehouseReceipt.create!(receipt_number: "RM0002026000001",
                             issued_on: Date.current, consignee: @cliente)
    duplicate = build_wr(receipt_number: "rm0002026000001")
    assert_not duplicate.valid?
  end

  test "status debe estar en STATUSES" do
    assert_not build_wr(receipt_number: "X", status: "invalido").valid?
  end

  test "repackaging_type acepta solo valores válidos" do
    assert_not build_wr(receipt_number: "X", repackaging_type: "invalido").valid?
  end

  test "permite repackaging_type nil" do
    assert build_wr(receipt_number: "X").valid?
  end

  test "calcula total_weight_kg desde lb" do
    wr = WarehouseReceipt.new(total_weight_lb: 100.0)
    assert_in_delta 45.36, wr.total_weight_kg, 0.05
  end

  test "calcula total_volume_m3 desde cuft" do
    wr = WarehouseReceipt.new(total_volume_cuft: 10.0)
    assert_in_delta 0.2832, wr.total_volume_m3, 0.001
  end

  test "declared_value setter convierte a cents" do
    wr = WarehouseReceipt.new
    wr.declared_value = 25.50
    assert_equal 2550, wr.declared_value_cents
    assert_equal 25.50, wr.declared_value
  end

  test "abandoned_at calcula 30 días desde issued_on" do
    wr = WarehouseReceipt.new(issued_on: Date.new(2026, 1, 1))
    assert_equal Date.new(2026, 1, 31), wr.abandoned_at
  end

  test "scope recientes ordena por issued_on desc" do
    wr1 = build_wr(receipt_number: "WR1", issued_on: Date.new(2026, 1, 1)).tap(&:save!)
    wr2 = build_wr(receipt_number: "WR2", issued_on: Date.new(2026, 2, 1)).tap(&:save!)
    assert_equal [ wr2, wr1 ], WarehouseReceipt.recientes.to_a.first(2)
  end

  test "scope activos excluye abandonados" do
    draft = build_wr(receipt_number: "D1", status: "draft").tap(&:save!)
    abandoned = build_wr(receipt_number: "D2", status: "abandoned").tap(&:save!)
    assert_includes WarehouseReceipt.activos, draft
    assert_not_includes WarehouseReceipt.activos, abandoned
  end

  test "belongs_to consignee con class_name Cliente" do
    wr = build_wr(receipt_number: "WR-CONS").tap(&:save!)
    assert_equal @cliente, wr.consignee
  end

  test "permite supplier nil (caso ENTREGA PERSONAL sin proveedor real)" do
    assert build_wr(receipt_number: "X", supplier: nil).valid?
  end

  # ── Edge cases en cálculos LB↔KG y cuft↔m³ ──

  test "total_weight_kg con cero devuelve cero" do
    wr = WarehouseReceipt.new(total_weight_lb: 0)
    assert_equal 0.0, wr.total_weight_kg
  end

  test "total_weight_kg con nil devuelve cero (defensivo)" do
    wr = WarehouseReceipt.new
    assert_equal 0.0, wr.total_weight_kg
  end

  test "total_weight_kg con valor grande mantiene precisión 2-decimales" do
    wr = WarehouseReceipt.new(total_weight_lb: 100_000.0)
    # 100_000 * 0.4535924 = 45_359.24
    assert_in_delta 45_359.24, wr.total_weight_kg, 0.05
    # No debe haber explosión a Float::INFINITY ni overflow
    assert wr.total_weight_kg.finite?
  end

  test "total_volumetric_weight_kg redondea a 2 decimales (no floating-point drift)" do
    wr = WarehouseReceipt.new(total_volumetric_weight_lb: 0.1) # 0.1 es problemático en floats
    # Resultado debe terminar en .05 redondeado a 2 decimales, no en 0.04535924...
    decimals = wr.total_volumetric_weight_kg.to_s.split(".").last
    assert_operator decimals.length, :<=, 2, "esperaba ≤2 decimales, got #{wr.total_volumetric_weight_kg}"
  end

  test "total_volume_m3 con valor pequeño preserva precisión 4-decimales" do
    wr = WarehouseReceipt.new(total_volume_cuft: 0.5)
    # 0.5 * 0.0283168 = 0.0141584 → redondeado a 4 = 0.0142
    assert_in_delta 0.0142, wr.total_volume_m3, 0.0001
  end

  test "total_volume_m3 con cero devuelve cero" do
    wr = WarehouseReceipt.new(total_volume_cuft: 0)
    assert_equal 0.0, wr.total_volume_m3
  end

  # ── declared_value setter contract ──

  test "declared_value=0 setea cents en 0" do
    wr = WarehouseReceipt.new
    wr.declared_value = 0
    assert_equal 0, wr.declared_value_cents
    assert_equal 0.0, wr.declared_value
  end

  test "declared_value redondea half cent al entero más cercano" do
    wr = WarehouseReceipt.new
    wr.declared_value = 12.345  # 1234.5 cents → round → 1235
    assert_equal 1235, wr.declared_value_cents
    assert_equal 12.35, wr.declared_value
  end

  test "declared_value_cents asignado directo se lee correctamente vía declared_value" do
    # Asegura que escritura directa al cents column NO rompe el getter (cents es source of truth).
    wr = WarehouseReceipt.new(declared_value_cents: 99_999)
    assert_equal 999.99, wr.declared_value
  end
end
