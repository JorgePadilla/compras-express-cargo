require "test_helper"

# PR-10.e: Yusef corrigió el etiquetado de /entrega_personal —
# "aquí tenés mal: aquí es proveedor y aquí es el driver".
#
#   Proveedor = la EMPRESA que mandó el paquete ("viene Walmart y te manda el
#               driver" → "sí, correcto")
#   Driver    = la PERSONA que lo trajo, campo aparte y editable, que se
#               imprime en la etiqueta ("por el rótulo")
class PaqueteDriverTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:digitador).email_address,
                                password: "password123" }
  end

  test "el label del proveedor ya no dice Driver" do
    get new_entrega_personal_url

    assert_response :success
    assert_no_match(/Proveedor \/ Driver/, response.body,
                    "proveedor y driver son dos cosas distintas")
  end

  test "entrega personal tiene campo propio para el driver" do
    get new_entrega_personal_url

    assert_response :success
    assert_match "paquete[driver]", response.body
    assert_match "Driver / Quien lo trajo", response.body
  end

  test "remitente y driver conviven — son datos distintos" do
    get new_entrega_personal_url

    # "remitente o quien envía está bien, pero igual otro driver"
    assert_match "paquete[remitente]", response.body
    assert_match "paquete[driver]", response.body
  end

  test "guarda el driver al crear una entrega personal" do
    assert_difference("Paquete.count") do
      post entrega_personal_index_url, params: { paquete: {
        cliente_id: clientes(:juan).id,
        tipo_envio_id: tipo_envios(:express).id,
        proveedor_id: proveedores(:driver_entrega).id,
        sucursal_id: sucursales(:miami).id,
        peso: 3.0, descripcion: "Caja",
        remitente: "Tienda Walmart",
        driver: "Juan Carlos Mejia"
      } }
    end

    p = Paquete.last
    assert_equal "Juan Carlos Mejia", p.driver
    assert_equal "Tienda Walmart", p.remitente, "el remitente no se pisa con el driver"
  end

  test "el driver sale impreso en la etiqueta" do
    p = paquetes(:recibido)
    p.update!(driver: "Juan Carlos Mejia")

    get etiqueta_paquete_url(p)

    assert_response :success
    assert_match "Driver:", response.body
    assert_match "JUAN CARLOS MEJIA", response.body
  end

  test "sin driver la etiqueta no muestra la fila vacia" do
    p = paquetes(:recibido)
    p.update!(driver: nil)

    get etiqueta_paquete_url(p)

    assert_response :success
    assert_no_match(/Driver:/, response.body)
  end
end
