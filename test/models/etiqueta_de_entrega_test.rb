require "test_helper"

# C30-19 · PR-P.3 · Lo que lleva la etiqueta de entrega 4×6.
#
#   > "Trae un QR para entregarle al cliente, trae el tipo de envío, a qué
#   >  prefactura está amarrada, el código del cliente, el nombre, las libras
#   >  a cobrar… y el volumen… la sucursal donde se retira, la fecha."
class EtiquetaDeEntregaTest < ActiveSupport::TestCase
  setup do
    @pf = PreFactura.create!(cliente: clientes(:juan), creado_por: users(:cajero), fecha_trabajo: Date.new(2026, 10, 9))
  end

  def paquete(**extra)
    Paquete.create!({ tracking: "1ZENT#{SecureRandom.hex(5).upcase}", cliente: clientes(:juan),
                      tipo_envio: tipo_envios(:cer), sucursal_recepcion: sucursales(:miami),
                      estado: "en_aduana", descripcion: "Ropa", peso: 5 }.merge(extra))
  end

  def flete(paquete, peso)
    @pf.pre_factura_items.create!(concepto: "Flete", paquete: paquete, peso_cobrar: peso, precio_libra: 1)
  end

  def etiqueta = EtiquetaDeEntrega.new(@pf.reload)

  # Con espacio y no `|`, como el QR de medición: una pistola en es-419 puede
  # no entregar la barra.
  test "el QR es ENT y el número de la pre-factura" do
    assert_equal "ENT #{@pf.numero}", etiqueta.qr
  end

  test "las libras a cobrar suman solo las líneas de flete" do
    flete(paquete, 10.5)
    flete(paquete, 4.25)
    @pf.pre_factura_items.create!(concepto: "Manejo", subtotal: 30)   # un cargo a mano, sin libras
    @pf.pre_factura_items.create!(concepto: "Recolecta", subtotal: 50, peso_cobrar: 99, origen: "auto_recolecta")

    assert_equal BigDecimal("14.75"), etiqueta.libras
  end

  test "el tipo de envío sale de lo que se cobra" do
    flete(paquete, 1)
    flete(paquete(tipo_envio: tipo_envios(:cem)), 1)

    assert_equal [ tipo_envios(:cem).nombre, tipo_envios(:cer).nombre ].sort.join(" · "), etiqueta.tipo_envio
  end

  test "sin paquetes no inventa tipo de envío" do
    @pf.pre_factura_items.create!(concepto: "Manejo", subtotal: 30)

    assert_nil etiqueta.tipo_envio
  end

  # Dónde retira: la del paquete, y si no tiene, la de la ficha del cliente.
  test "la sucursal de retiro es la del paquete" do
    clientes(:juan).update_columns(sucursal_retiro_id: sucursales(:humuya_tgu).id)
    flete(paquete(sucursal: sucursales(:zeron_sps)), 1)

    assert_equal sucursales(:zeron_sps), etiqueta.sucursal
  end

  test "sin sucursal en el paquete, la del cliente" do
    clientes(:juan).update_columns(sucursal_retiro_id: sucursales(:humuya_tgu).id)
    flete(paquete(sucursal: nil), 1)

    assert_equal sucursales(:humuya_tgu), etiqueta.sucursal
  end

  # RP-82, provisorio: un volumen es una medición; lo que no se midió cuenta
  # como su propio volumen, con el volumétrico de Miami.
  test "el volumen: cuántos y sus VLBS, medidos o no" do
    sesion = SecureRandom.uuid
    Bulto.create!(cliente: clientes(:juan), sesion: sesion, orden: 1, de_cuantos: 2, medido_at: Time.current,
                  peso: 10, alto: 10, largo: 10, ancho: 16.6)                  # 10 VLBS
    Bulto.create!(cliente: clientes(:juan), sesion: sesion, orden: 2, de_cuantos: 2, medido_at: Time.current,
                  peso: 10, alto: 10, largo: 10, ancho: 33.2)                  # 20 VLBS
    flete(paquete(medicion_sesion: sesion), 1)
    flete(paquete(medicion_sesion: sesion), 1)
    suelto = paquete
    suelto.update_columns(peso_volumetrico: 7.5)
    flete(suelto, 1)

    assert_equal 3, etiqueta.volumenes
    assert_equal BigDecimal("37.5"), etiqueta.vlbs
  end

  test "la fecha es la de trabajo, sin hora mientras no exista la del aviso" do
    assert_equal "09/10/2026", etiqueta.fecha
  end

  # PR-P.2 trae `consolidando_at`. Hasta entonces la franja no sale nunca, y
  # cuando la columna exista sale sola.
  test "consolidando solo si la pre-factura lo dice" do
    assert_not etiqueta.consolidando?

    pf = @pf.reload
    pf.define_singleton_method(:consolidando_at) { Time.current }
    assert EtiquetaDeEntrega.new(pf).consolidando?
  end
end
