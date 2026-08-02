require "test_helper"

class NumeroRecepcionCounterTest < ActiveSupport::TestCase
  setup do
    @sucursal = sucursales(:miami)
    NumeroRecepcionCounter.where(sucursal_id: @sucursal.id).delete_all
  end

  test "next_for! crea fila en 0 y devuelve 1 al primer call" do
    n = NumeroRecepcionCounter.next_for!(sucursal: @sucursal, anio: 2026)
    assert_equal 1, n

    counter = NumeroRecepcionCounter.find_by!(sucursal_id: @sucursal.id, anio: 2026)
    assert_equal 1, counter.ultimo_numero
  end

  test "next_for! incrementa secuencialmente para el mismo (sucursal, anio)" do
    a = NumeroRecepcionCounter.next_for!(sucursal: @sucursal, anio: 2026)
    b = NumeroRecepcionCounter.next_for!(sucursal: @sucursal, anio: 2026)
    c = NumeroRecepcionCounter.next_for!(sucursal: @sucursal, anio: 2026)
    assert_equal [ 1, 2, 3 ], [ a, b, c ]
  end

  test "next_for! reinicia el contador al cambiar de año" do
    a = NumeroRecepcionCounter.next_for!(sucursal: @sucursal, anio: 2026)
    b = NumeroRecepcionCounter.next_for!(sucursal: @sucursal, anio: 2026)
    c = NumeroRecepcionCounter.next_for!(sucursal: @sucursal, anio: 2027)

    assert_equal 1, a
    assert_equal 2, b
    assert_equal 1, c, "el primer paquete del 2027 debe arrancar en 1"
  end

  test "next_for! mantiene contadores independientes por sucursal" do
    otra = sucursales(:zeron_sps)
    NumeroRecepcionCounter.where(sucursal_id: otra.id).delete_all

    a = NumeroRecepcionCounter.next_for!(sucursal: @sucursal, anio: 2026)
    b = NumeroRecepcionCounter.next_for!(sucursal: otra,     anio: 2026)
    c = NumeroRecepcionCounter.next_for!(sucursal: @sucursal, anio: 2026)

    assert_equal 1, a
    assert_equal 1, b
    assert_equal 2, c
  end

  test "unique index impide dos counters para (sucursal_id, anio)" do
    NumeroRecepcionCounter.create!(sucursal: @sucursal, anio: 2026, ultimo_numero: 0)
    assert_raises(ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid) do
      NumeroRecepcionCounter.create!(sucursal: @sucursal, anio: 2026, ultimo_numero: 0)
    end
  end
end
