require "test_helper"

# Un tracking, N cajas — `PR-C7.16`.
#
# Yusef mandó el WR de un envío de 3 cajas: *"el Warehouse Receipt sí está malo,
# porque **solo sale por una caja**"*. La causa no estaba en el WR.
#
# Los trackings autogenerados (EP y RC) salen de un `before_validation on:
# :create` cuyo único guard es `tracking.blank?`. En un split eso corría una vez
# **por caja**, así que las tres salían con números distintos —`…000003`,
# `…000004`, `…000005`— y el contador avanzaba tres veces.
#
# Y todo lo que agrupa un split lo hace por `tracking`: `paquetes_hermanos`,
# `wr_packages_for` y `etiqueta?hermanas=1`. Con tres trackings distintos los
# hermanos eran cero: el WR listaba una fila mientras el badge decía "SPLIT 3
# CAJAS", y las etiquetas salían de a una.
class SplitUnSoloTrackingTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
    @miami   = sucursales(:miami)                        # codigo_ep = SMI
    @driver  = Proveedor.create!(nombre: "Split Driver", tipo: "entrega_personal")
    @cer     = tipo_envios(:cer)
  end

  def crear(total: 3, **extra)
    Paquete.crear_split!(
      attrs: { cliente: @cliente, tipo_envio: @cer, proveedor: @driver,
               sucursal_recepcion: @miami, user: users(:admin),
               estado: "recibido_miami" }.merge(extra),
      total_cajas: total,
      por_caja: { 1 => { peso: 5, alto: 10, largo: 5,  ancho: 15 },
                  2 => { peso: 8, alto: 12, largo: 6,  ancho: 20 },
                  3 => { peso: 2, alto: 30, largo: 30, ancho: 30 } }
    )
  end

  test "las tres cajas comparten un solo tracking EP" do
    cajas = crear

    assert_equal 1, cajas.map(&:tracking).uniq.size,
                 "cada caja sacó su propio número EP: #{cajas.map(&:tracking).inspect}"
    assert_match(/\AEP-\d{4}-SMI-#{@driver.codigo}-\d{6}\z/, cajas.first.tracking)
  end

  # El síntoma que Yusef vio, dicho como test.
  test "desde cualquier caja se llega a las otras dos" do
    cajas = crear

    cajas.each do |caja|
      assert_equal 2, caja.paquetes_hermanos.count,
                   "la caja #{caja.numero_caja} no encuentra a sus hermanas"
    end
  end

  test "el contador avanza una sola vez, no una por caja" do
    crear
    primero = Paquete.where(cliente: @cliente).order(:id).last.tracking

    crear
    segundo = Paquete.where(cliente: @cliente).order(:id).last.tracking

    numero = ->(t) { t[/(\d{6})\z/, 1].to_i }
    assert_equal 1, numero.call(segundo) - numero.call(primero),
                 "el segundo envío saltó #{numero.call(segundo) - numero.call(primero)} números"
  end

  # La recolecta vive dentro de la pantalla de Entrega Personal desde A7-22, y su
  # generador tiene exactamente la misma forma.
  test "la recolecta tambien comparte tracking entre cajas" do
    cajas = crear(recolecta_solicitada: true, proveedor: proveedores(:Amazon))

    assert_equal 1, cajas.map(&:tracking).uniq.size
    assert_match(/\ARC-/, cajas.first.tracking)
  end

  test "un tracking que trae el operador se respeta y se comparte" do
    cajas = crear(tracking: "1Z999SPLIT")

    assert_equal [ "1Z999SPLIT" ], cajas.map(&:tracking).uniq
  end

  # ── La sucursal que numera es la de recepción ─────────────────────────────
  #
  # `Paquete#sucursal` es **dónde retira el cliente**. Antes el generador leía
  # ese campo y funcionaba solo porque /entrega_personal metía ahí la sucursal de
  # Miami — el mismo bug que hacía que la etiqueta dijera "RETIRA EN MIAMI".

  test "el prefijo sale de la sucursal de recepcion, no de la de retiro" do
    p = Paquete.create!(cliente: @cliente, proveedor: @driver, tracking: nil,
                        sucursal_recepcion: @miami, sucursal: sucursales(:humuya_tgu))

    assert_match(/\AEP-\d{4}-SMI-/, p.tracking,
                 "tomó el código de la sucursal de retiro en vez de la de recepción")
  end

  # Los EP viejos se crearon con la sucursal de Miami en `sucursal`; el fallback
  # de `sucursal_del_numero` los deja andando.
  test "sin sucursal de recepcion cae en la de retiro, como antes" do
    p = Paquete.create!(cliente: @cliente, proveedor: @driver, tracking: nil,
                        sucursal: @miami)

    assert_match(/\AEP-\d{4}-SMI-/, p.tracking)
  end
end
