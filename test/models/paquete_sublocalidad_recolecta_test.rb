require "test_helper"

# PR-D1.c: tests para sucursal_actual / sub_localidad_actual / recolecta.
class PaqueteSublocalidadRecolectaTest < ActiveSupport::TestCase
  setup do
    @cliente  = clientes(:juan)
    @sucursal = sucursales(:miami)
    @otra_sucursal = sucursales(:zeron_sps)
  end

  test "puede asignar sucursal_actual y sub_localidad_actual válidos" do
    sub = SubLocalidad.create!(sucursal: @sucursal, codigo: "MI01", nombre: "Bodega Miami 1")
    p = Paquete.create!(
      tracking: "1Z999SL_A", cliente: @cliente, sucursal: @sucursal,
      sucursal_actual: @sucursal, sub_localidad_actual: sub
    )
    assert_equal @sucursal, p.sucursal_actual
    assert_equal sub, p.sub_localidad_actual
  end

  test "valida que sub_localidad_actual pertenezca a sucursal_actual" do
    sub_zeron = SubLocalidad.create!(sucursal: @otra_sucursal, codigo: "ZR99", nombre: "Test Zerón")
    p = Paquete.new(
      tracking: "1Z999SL_B", cliente: @cliente, sucursal: @sucursal,
      sucursal_actual: @sucursal, sub_localidad_actual: sub_zeron
    )
    assert_not p.valid?
    assert p.errors[:sub_localidad_actual].any?
  end

  test "permite sub_localidad_actual nil (no todas las sucursales tienen)" do
    p = Paquete.new(
      tracking: "1Z999SL_C", cliente: @cliente, sucursal: @sucursal,
      sucursal_actual: @sucursal, sub_localidad_actual: nil
    )
    assert p.valid?
  end

  test "recolecta default $35 USD cuando se solicita y monto está vacío" do
    p = Paquete.create!(
      tracking: "1Z999RE_A", cliente: @cliente, sucursal: @sucursal,
      recolecta_solicitada: true
    )
    assert_equal 35.0, p.recolecta_monto.to_f
    assert_equal "USD", p.recolecta_moneda
  end

  test "recolecta NO se auto-llena si se pasa monto explícito" do
    p = Paquete.create!(
      tracking: "1Z999RE_B", cliente: @cliente, sucursal: @sucursal,
      recolecta_solicitada: true, recolecta_monto: 50.0
    )
    assert_equal 50.0, p.recolecta_monto.to_f
  end

  test "sin recolecta_solicitada el monto queda nil" do
    p = Paquete.create!(tracking: "1Z999RE_C", cliente: @cliente, sucursal: @sucursal)
    assert_not p.recolecta_solicitada?
    assert_nil p.recolecta_monto
  end

  test "RECOLECTA_TARIFA_DEFAULT_USD constante = 35" do
    assert_equal 35.0, Paquete::RECOLECTA_TARIFA_DEFAULT_USD
  end
end
