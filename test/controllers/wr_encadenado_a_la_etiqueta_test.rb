require "test_helper"

# Yusef: *"si después de imprimir la etiqueta, te tire automáticamente el Recibo
# de Bodega"*. Ver `test/system/wr_despues_de_la_etiqueta_test.rb` para la
# reproducción del bloqueador de popups — esto es la mitad que **sí corre en
# CI**, porque CI no corre `test/system`.
class WrEncadenadoALaEtiquetaTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: {
      email_address: users(:digitador).email_address, password: "password123"
    }
    @paquete = paquetes(:disponible_entrega_juan)
  end

  test "con wr=1 la etiqueta lleva a donde ir despues de imprimir" do
    get etiqueta_paquete_url(@paquete, print: true, wr: 1)

    assert_response :success
    assert_includes response.body, warehouse_receipt_paquete_path(@paquete)
  end

  test "sin wr=1 no lleva ningun destino" do
    # Las demás pantallas imprimen etiquetas y punto: en un lote de 100 paquetes
    # esto abriría 100 Warehouse Receipts.
    get etiqueta_paquete_url(@paquete, print: true)

    assert_response :success
    assert_not_includes response.body, warehouse_receipt_paquete_path(@paquete)
    assert_includes response.body, "var despues = \"\""
  end

  test "el destino lo arma el servidor, no un parametro" do
    # Un parámetro con la dirección de destino sería un redirect abierto
    # servido desde nuestro propio dominio.
    get etiqueta_paquete_url(@paquete, print: true, wr: 1, despues: "https://evil.example/x")

    assert_response :success
    assert_not_includes response.body, "evil.example"
  end

  test "entrega personal abre una sola ventana y le pide el WR encadenado" do
    # La causa exacta de lo que reportó Yusef: eran dos `window.open` seguidas y
    # Chrome bloquea la segunda. Un gesto del usuario le alcanza para un popup.
    src = Rails.root.join("app/javascript/controllers/entrega_personal_controller.js").read

    assert_equal 1, src.scan("window.open(").size,
                 "volvió a abrir más de un popup: el segundo se lo come el navegador"
    assert_includes src, "print=true&wr=1"
  end
end
