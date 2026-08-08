require "test_helper"

# PR-10.h: la pantalla de selección de paquetes tiene que mostrar el mismo
# precio que la pre-factura va a cobrar.
#
# Venía calculándolo con la cadena vieja (`categoria_precio.precio_para ||
# tipo_envio.precio_libra`): sin mínimos, sin escalones, y sin convertir a
# Lempiras — pero rotulado "L.". El mismo bug de moneda que PR-10.a arregló en
# `build_from_paquetes`, en el camino que quedó afuera.
#
# Mientras las tarifas eran un backfill plano la diferencia no se notaba. Con
# los precios reales de Yusef (PR-10.g) un CER de 0.5 lb mostraba $2.25 y la
# pre-factura cobraba L.173.91.
#
# Yusef: "queremos que el área de los precios estén establecidos, listo". Mal
# puede estar preestablecido si la pantalla dice un número y el sistema cobra
# otro.
class PreFacturaPreviewPrecioTest < ActionDispatch::IntegrationTest
  setup do
    TarifasPropuesta2026.sembrar!
    post session_url, params: { email_address: users(:cajero).email_address,
                                password: "password123" }
    @cliente = clientes(:juan)
  end

  test "el precio del preview es el mismo que cobra la pre-factura" do
    paquete = paquete_facturable(tipo_envio: tipo_envios(:cer), peso: 10)

    get facturables_pre_facturas_url, params: { cliente_id: @cliente.id }, as: :json
    fila = JSON.parse(response.body).find { |f| f["id"] == paquete.id }

    pre_factura = PreFactura.build_from_paquetes(@cliente, [ paquete.id ], user: users(:cajero))
    item = pre_factura.pre_factura_items.first

    assert_in_delta item.precio_libra.to_f, fila["precio_libra"], 0.001,
                    "el preview muestra otro precio por libra que la pre-factura"
    assert_in_delta item.subtotal.to_f, fila["subtotal"], 0.001,
                    "el preview muestra otro subtotal que la pre-factura"
  end

  test "coinciden tambien cuando aplica el minimo" do
    # El caso que más se separaba: 0.5 lb de CER cae bajo el mínimo de
    # L.173.91, y el cálculo viejo mostraba 0.5 × $4.50 = 2.25.
    paquete = paquete_facturable(tipo_envio: tipo_envios(:cer), peso: 0.5)

    get facturables_pre_facturas_url, params: { cliente_id: @cliente.id }, as: :json
    fila = JSON.parse(response.body).find { |f| f["id"] == paquete.id }

    assert fila["aplico_minimo"], "0.5 lb de CER tiene que caer en el mínimo"
    assert_in_delta 173.91, fila["subtotal"], 0.01
    assert_equal "LPS", fila["moneda"]

    pre_factura = PreFactura.build_from_paquetes(@cliente, [ paquete.id ], user: users(:cajero))
    assert_in_delta pre_factura.pre_factura_items.first.subtotal.to_f, fila["subtotal"], 0.001
  end

  test "el preview usa el escalon de peso, no un precio plano" do
    liviano = paquete_facturable(tipo_envio: tipo_envios(:cer), peso: 10)
    pesado  = paquete_facturable(tipo_envio: tipo_envios(:cer), peso: 75)

    get facturables_pre_facturas_url, params: { cliente_id: @cliente.id }, as: :json
    filas = JSON.parse(response.body).index_by { |f| f["id"] }

    tasa = CurrencyAware.tasa_vigente.to_f
    assert_in_delta 4.50 * tasa, filas[liviano.id]["precio_libra"], 0.01
    assert_in_delta 4.00 * tasa, filas[pesado.id]["precio_libra"], 0.01,
                    "a 75 lb el CER baja al escalón de $4.00"
  end

  test "la pantalla imprime el monto convertido, no el de dolares" do
    paquete_facturable(tipo_envio: tipo_envios(:cer), peso: 10)

    get new_pre_factura_url, params: { cliente_id: @cliente.id }

    assert_response :success
    # Se convierte el precio unitario y sobre ese se multiplica, para que en la
    # factura impresa cuadre peso × precio = subtotal: $4.50 × 24.85 = L.111.83,
    # y 10 × 111.83 = L.1,118.30. No "L. 45.00".
    assert_match "111.83", response.body
    assert_match "1,118.30", response.body
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
