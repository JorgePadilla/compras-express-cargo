require "test_helper"
require Rails.root.join("db/migrate/20261013200000_sucursal_retiro_por_defecto_en_clientes_sin_ella").to_s

# Los clientes sin «Sucursal donde retira» pasan a la de por defecto. Yusef,
# 2026-10-12: *"cuando no tiene sucursal esto debería ser San Pedro… ahorita
# default San Pedro Zerón"*. Se corre la migración de verdad (su `up`).
class SucursalRetiroPorDefectoEnClientesTest < ActiveSupport::TestCase
  def migrar
    migracion = SucursalRetiroPorDefectoEnClientesSinElla.new
    migracion.verbose = false
    migracion.up
  end

  setup do
    @sps = sucursales(:zeron_sps)
    @tgu = sucursales(:humuya_tgu)
    @sin = Cliente.create!(nombre: "Sin sucursal")
    @con = Cliente.create!(nombre: "Retira en Humuya", sucursal_retiro: @tgu)
  end

  test "llena la de retiro por defecto, y no toca a quien ya tenía una" do
    @sps.update_columns(retiro_por_defecto: true)

    migrar

    assert_equal @sps, @sin.reload.sucursal_retiro
    assert_equal @tgu, @con.reload.sucursal_retiro, "la que eligió el cliente no se pisa"
  end

  test "si nadie marcó una por defecto, usa la de código SPS" do
    Sucursal.update_all(retiro_por_defecto: false)

    migrar

    assert_equal @sps, @sin.reload.sucursal_retiro
  end

  test "sin ninguna de las dos no inventa: deja el vacío como estaba" do
    Sucursal.update_all(retiro_por_defecto: false)
    @sps.update_columns(codigo: "XSP")

    migrar

    assert_nil @sin.reload.sucursal_retiro_id
  end
end
