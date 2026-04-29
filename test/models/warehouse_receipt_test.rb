require "test_helper"

class WarehouseReceiptTest < ActiveSupport::TestCase
  test "valid con campos requeridos" do
    wr = WarehouseReceipt.new(
      receipt_number: "RM0002026000001",
      issued_on: Date.current,
      status: "draft"
    )
    assert wr.valid?
  end

  test "receipt_number es requerido y único case-insensitive" do
    WarehouseReceipt.create!(receipt_number: "RM0002026000001", issued_on: Date.current)
    duplicate = WarehouseReceipt.new(receipt_number: "rm0002026000001", issued_on: Date.current)
    assert_not duplicate.valid?
  end

  test "status debe estar en STATUSES" do
    wr = WarehouseReceipt.new(receipt_number: "X", issued_on: Date.current, status: "invalido")
    assert_not wr.valid?
  end

  test "repackaging_type acepta solo valores válidos" do
    wr = WarehouseReceipt.new(receipt_number: "X", issued_on: Date.current,
                              repackaging_type: "invalido")
    assert_not wr.valid?
  end

  test "permite repackaging_type nil" do
    wr = WarehouseReceipt.new(receipt_number: "X", issued_on: Date.current)
    assert wr.valid?
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
    wr1 = WarehouseReceipt.create!(receipt_number: "WR1", issued_on: Date.new(2026, 1, 1))
    wr2 = WarehouseReceipt.create!(receipt_number: "WR2", issued_on: Date.new(2026, 2, 1))
    assert_equal [ wr2, wr1 ], WarehouseReceipt.recientes.to_a.first(2)
  end

  test "scope activos excluye abandonados" do
    draft = WarehouseReceipt.create!(receipt_number: "D1", issued_on: Date.current, status: "draft")
    abandoned = WarehouseReceipt.create!(receipt_number: "D2", issued_on: Date.current, status: "abandoned")
    assert_includes WarehouseReceipt.activos, draft
    assert_not_includes WarehouseReceipt.activos, abandoned
  end

  test "belongs_to consignee con class_name Cliente" do
    cliente = clientes(:juan)
    wr = WarehouseReceipt.create!(receipt_number: "WR-CONS",
                                  issued_on: Date.current, consignee: cliente)
    assert_equal cliente, wr.consignee
  end

  test "permite supplier nil (caso ENTREGA PERSONAL sin proveedor real)" do
    wr = WarehouseReceipt.new(receipt_number: "X", issued_on: Date.current, supplier: nil)
    assert wr.valid?
  end
end
