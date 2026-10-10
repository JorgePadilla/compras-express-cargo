require "test_helper"

# PR-10.h: lo que se le muestra al cliente antes tiene que ser lo que la
# pre-factura cobra.
#
# Venía calculándose con la cadena vieja (`categoria_precio.precio_para ||
# tipo_envio.precio_libra`): sin mínimos, sin escalones, y sin convertir a
# Lempiras — pero rotulado "L.". Con los precios reales de Yusef (PR-10.g) un
# CER de 0.5 lb mostraba $2.25 y la pre-factura cobraba L.173.91.
#
# Yusef: "queremos que el área de los precios estén establecidos, listo". Mal
# puede estar preestablecido si la pantalla dice un número y el sistema cobra
# otro.
#
# PR-P.11b · Era el test del JSON del preview de la pre-factura a mano, que se
# fue. Lo que cuidaba sigue valiendo: `CotizadorFlete` —el que usan
# /entrega_personal y el armador por volumen— cobra lo mismo que la línea de
# la pre-factura, con las tarifas sembradas de verdad.
class CotizadorFleteCobraLoQueLaPreFacturaTest < ActionDispatch::IntegrationTest
  setup do
    TarifasPropuesta2026.sembrar!
    post session_url, params: { email_address: users(:cajero).email_address,
                                password: "password123" }
    @cliente = clientes(:juan)
  end

  def cotizar(paquete)
    CotizadorFlete.call(tipo_envio: paquete.tipo_envio, cliente: @cliente, proveedor: paquete.proveedor,
                        sucursal: paquete.sucursal, peso: paquete.peso_cobrar)
  end

  test "el cotizador cobra lo mismo que la pre-factura" do
    paquete = paquete_facturable(tipo_envio: tipo_envios(:cer), peso: 10)
    cot = cotizar(paquete)

    item = PreFactura.build_from_paquetes(@cliente, [ paquete.id ], user: users(:cajero)).pre_factura_items.first

    assert_in_delta item.precio_libra.to_f, cot.precio_libra.to_f, 0.001, "otro precio por libra que la pre-factura"
    assert_in_delta item.subtotal.to_f, cot.subtotal.to_f, 0.001, "otro subtotal que la pre-factura"
  end

  test "coinciden tambien cuando aplica el minimo" do
    # El caso que más se separaba: 0.5 lb de CER cae bajo el mínimo de
    # L.173.91, y el cálculo viejo mostraba 0.5 × $4.50 = 2.25.
    paquete = paquete_facturable(tipo_envio: tipo_envios(:cer), peso: 0.5)
    cot = cotizar(paquete)

    assert cot.aplico_minimo, "0.5 lb de CER tiene que caer en el mínimo"
    assert_in_delta 173.91, cot.subtotal.to_f, 0.01
    assert_equal "LPS", cot.moneda

    pre_factura = PreFactura.build_from_paquetes(@cliente, [ paquete.id ], user: users(:cajero))
    assert_in_delta pre_factura.pre_factura_items.first.subtotal.to_f, cot.subtotal.to_f, 0.001
  end

  test "usa el escalon de peso, no un precio plano" do
    liviano = paquete_facturable(tipo_envio: tipo_envios(:cer), peso: 10)
    pesado  = paquete_facturable(tipo_envio: tipo_envios(:cer), peso: 75)

    tasa = CurrencyAware.tasa_vigente.to_f
    assert_in_delta 4.50 * tasa, cotizar(liviano).precio_libra.to_f, 0.01
    assert_in_delta 4.00 * tasa, cotizar(pesado).precio_libra.to_f, 0.01,
                    "a 75 lb el CER baja al escalón de $4.00"
  end

  test "la pre-factura imprime el monto convertido, no el de dolares" do
    paquete = paquete_facturable(tipo_envio: tipo_envios(:cer), peso: 10)
    pf = PreFactura.build_from_paquetes(@cliente, [ paquete.id ], user: users(:cajero)).tap(&:save!)

    get pre_factura_url(pf)

    assert_response :success
    # Se convierte el precio unitario y sobre ese se multiplica, para que en la
    # factura impresa cuadre peso × precio = subtotal. No "L. 45.00".
    # Como lo pinta la vista (`number_with_delimiter` del Float).
    item = pf.pre_factura_items.first
    assert_match "L. #{ActiveSupport::NumberHelper.number_to_delimited(item.precio_libra.to_f)}", response.body
    assert_match "L. #{ActiveSupport::NumberHelper.number_to_delimited(item.subtotal.to_f)}", response.body
    assert_equal (item.precio_libra * 10).round(2), item.subtotal, "peso × precio = subtotal, a la vista"
    assert_no_match(/L\.\s*45\.00/, response.body)
  end

  private

  def paquete_facturable(tipo_envio:, peso:)
    @seq = (@seq || 0) + 1
    Paquete.create!(
      tracking: "PREVIEW#{@seq}#{peso.to_s.delete('.')}",
      cliente: @cliente,
      tipo_envio: tipo_envio,
      sucursal: sucursales(:zeron_sps),
      estado: "disponible_entrega",
      peso: peso,
      peso_cobrar: peso,
      cantidad_productos: 1,
      cantidad_paquetes: 1,
      descripcion: "Paquete de prueba",
      user: users(:digitador)
    )
  end
end
