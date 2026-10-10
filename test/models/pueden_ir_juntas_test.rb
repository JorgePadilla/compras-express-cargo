require "test_helper"

# PR-P.11a · «NO Mezclar» sabe ahora lo que solo resolvía la pre-factura a mano.
#
# Dos clases de regla: las de la **pre-factura** (cliente, servicio, sucursal
# de retiro, consolidado), que corren en Medición, en Auditar y en F9; y las
# del **volumen** (prepago, tarifa, trato de cobro), que corren solo dentro de
# una tanda de Medición (`misma_tanda: true`): dos tandas distintas sí van en
# una pre-factura, cada volumen es su línea.
class PuedenIrJuntasTest < ActiveSupport::TestCase
  setup do
    Tarifa.delete_all
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD")
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 3.00, moneda: "USD", proveedor: proveedores(:Amazon))
  end

  def caja(**extra)
    Paquete.create!(tracking: "1ZPIJ#{SecureRandom.hex(5).upcase}", cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                    sucursal_recepcion: sucursales(:miami), estado: "en_aduana", descripcion: "Zapatos", peso: 2, **extra)
  end

  def motivo(ya, nueva, **opciones) = PuedenIrJuntas.new([ ya ], nueva, **opciones).problema&.motivo

  test "las reglas del volumen solo dentro de una tanda" do
    base = caja
    prepagada = caja(prepagado_miami: true, prepagado_miami_metodo: "efectivo")
    de_amazon = caja(proveedor: proveedores(:Amazon))
    solo_peso = caja.tap { |c| c.update_columns(cobro_excepcion: "solo_peso") }

    assert_equal "prepago_mezclado", motivo(base, prepagada, misma_tanda: true)
    assert_equal "otra_tarifa", motivo(base, de_amazon, misma_tanda: true)
    assert_equal "otro_trato_de_cobro", motivo(base, solo_peso, misma_tanda: true)

    assert_nil motivo(base, prepagada), "entre tandas (Auditar, F9) no"
    assert_nil motivo(base, de_amazon)
    assert_nil motivo(base, solo_peso)
  end

  test "otra sucursal de retiro, en todos lados" do
    sps = caja(sucursal: sucursales(:zeron_sps))
    tgu = caja(sucursal: sucursales(:humuya_tgu))

    assert_equal "otra_sucursal", motivo(sps, tgu)
    assert_equal "otra_sucursal", motivo(sps, tgu, misma_tanda: true)
    assert_nil motivo(sps, caja(sucursal: sucursales(:zeron_sps)), misma_tanda: true)
  end

  test "la tarifa se compara por el nivel que aplicaría, y Tarifa.clave cae donde cae resolver" do
    base = caja
    de_amazon = caja(proveedor: proveedores(:Amazon))
    cliente = clientes(:juan)

    [ base, de_amazon ].each do |c|
      clave = Tarifa.clave(tipo_envio: c.tipo_envio, cliente: cliente, proveedor: c.proveedor, sucursal: c.sucursal)
      tarifa = Tarifa.resolver(tipo_envio: c.tipo_envio, peso: 10, cliente: cliente, proveedor: c.proveedor, sucursal: c.sucursal)
      assert_equal [ tarifa.proveedor_id, tarifa.sucursal_id ], clave.values_at(:proveedor_id, :sucursal_id)
    end
    assert_not_equal Tarifa.clave(tipo_envio: tipo_envios(:cer), cliente: cliente),
                     Tarifa.clave(tipo_envio: tipo_envios(:cer), cliente: cliente, proveedor: proveedores(:Amazon))

    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.00, moneda: "USD", sucursal: sucursales(:zeron_sps))
    clave = Tarifa.clave(tipo_envio: tipo_envios(:cer), cliente: cliente, sucursal: sucursales(:zeron_sps))
    assert_equal sucursales(:zeron_sps).id, clave[:sucursal_id], "la fila de la sucursal pisa a la genérica"
    assert_nil Tarifa.clave(tipo_envio: tipo_envios(:cem), cliente: cliente), "sin tarifas, sin clave"
  end
end
