require "test_helper"

class ManifiestoCounterTest < ActiveSupport::TestCase
  setup do
    @sucursal = sucursales(:miami)
    ManifiestoCounter.where(sucursal_id: @sucursal.id).delete_all
  end

  test "next_for! crea fila en 0 y devuelve 1 al primer call" do
    n = ManifiestoCounter.next_for!(sucursal: @sucursal, anio: 2026)
    assert_equal 1, n
  end

  test "next_for! incrementa secuencialmente para el mismo (sucursal, anio)" do
    a = ManifiestoCounter.next_for!(sucursal: @sucursal, anio: 2026)
    b = ManifiestoCounter.next_for!(sucursal: @sucursal, anio: 2026)
    c = ManifiestoCounter.next_for!(sucursal: @sucursal, anio: 2026)
    assert_equal [ 1, 2, 3 ], [ a, b, c ]
  end

  test "next_for! reinicia el contador al cambiar de año" do
    ManifiestoCounter.next_for!(sucursal: @sucursal, anio: 2026)
    ManifiestoCounter.next_for!(sucursal: @sucursal, anio: 2026)
    n = ManifiestoCounter.next_for!(sucursal: @sucursal, anio: 2027)
    assert_equal 1, n, "el primer manifiesto del 2027 debe arrancar en 1"
  end

  test "counters independientes por sucursal" do
    otra = sucursales(:zeron_sps)
    ManifiestoCounter.where(sucursal_id: otra.id).delete_all

    a = ManifiestoCounter.next_for!(sucursal: @sucursal, anio: 2026)
    b = ManifiestoCounter.next_for!(sucursal: otra,     anio: 2026)
    c = ManifiestoCounter.next_for!(sucursal: @sucursal, anio: 2026)

    assert_equal 1, a
    assert_equal 1, b
    assert_equal 2, c
  end

  test "unique index impide dos counters para (sucursal_id, anio)" do
    ManifiestoCounter.create!(sucursal: @sucursal, anio: 2026, ultimo_numero: 0)
    assert_raises(ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid) do
      ManifiestoCounter.create!(sucursal: @sucursal, anio: 2026, ultimo_numero: 0)
    end
  end
end
