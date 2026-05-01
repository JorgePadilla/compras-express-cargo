require "test_helper"

class EpCounterTest < ActiveSupport::TestCase
  setup do
    @sucursal  = sucursales(:miami)
    @proveedor = Proveedor.create!(nombre: "EpTest Driver Uno", tipo: "entrega_personal")
  end

  test "next_for! crea counter inicial en 1" do
    n = EpCounter.next_for!(anio: 2027, sucursal: @sucursal, proveedor: @proveedor)
    assert_equal 1, n
  end

  test "next_for! incrementa atómicamente" do
    EpCounter.next_for!(anio: 2027, sucursal: @sucursal, proveedor: @proveedor)
    EpCounter.next_for!(anio: 2027, sucursal: @sucursal, proveedor: @proveedor)
    n = EpCounter.next_for!(anio: 2027, sucursal: @sucursal, proveedor: @proveedor)
    assert_equal 3, n
  end

  test "counter es independiente por (anio, sucursal, proveedor)" do
    otro_proveedor = Proveedor.create!(nombre: "EpTest Driver Dos", tipo: "entrega_personal")
    otra_sucursal  = sucursales(:zeron_sps)

    EpCounter.next_for!(anio: 2027, sucursal: @sucursal, proveedor: @proveedor) # combo A: 1
    EpCounter.next_for!(anio: 2027, sucursal: @sucursal, proveedor: @proveedor) # combo A: 2

    n_b = EpCounter.next_for!(anio: 2027, sucursal: @sucursal, proveedor: otro_proveedor)
    assert_equal 1, n_b, "otro proveedor mismo año/sucursal arranca en 1"

    n_c = EpCounter.next_for!(anio: 2027, sucursal: otra_sucursal, proveedor: @proveedor)
    assert_equal 1, n_c, "otra sucursal mismo año/proveedor arranca en 1"

    n_d = EpCounter.next_for!(anio: 2028, sucursal: @sucursal, proveedor: @proveedor)
    assert_equal 1, n_d, "nuevo año arranca en 1"
  end

  test "concurrencia: 5 incrementos secuenciales devuelven 1..5 sin colisión" do
    results = (1..5).map do
      EpCounter.next_for!(anio: 2027, sucursal: @sucursal, proveedor: @proveedor)
    end
    assert_equal [ 1, 2, 3, 4, 5 ], results
  end
end
