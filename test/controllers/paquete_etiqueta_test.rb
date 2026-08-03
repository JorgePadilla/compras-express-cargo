require "test_helper"

# PR-10.d: la etiqueta física (Dymo 2.25 × 1.25). Hasta ahora el sistema
# imprimía el Warehouse Receipt en hoja carta y se usaba como si fuera la
# etiqueta — Yusef: "aquí está tirando el warehouse, no la etiqueta".
class PaqueteEtiquetaTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:digitador).email_address,
                                password: "password123" }
    @paquete = paquetes(:recibido)
  end

  test "usa el layout de etiqueta, no el de carta" do
    get etiqueta_paquete_url(@paquete)

    assert_response :success
    assert_match "2.25in 1.25in", response.body, "debe declarar el tamaño Dymo"
    assert_no_match(/size: Letter/, response.body)
  end

  test "lleva codigo de barras del numero de recepcion" do
    get etiqueta_paquete_url(@paquete)

    assert_response :success
    assert_match "<svg", response.body, "el codigo de barras va en SVG inline"
  end

  test "muestra los campos que Yusef marco como necesarios" do
    get etiqueta_paquete_url(@paquete)
    body = response.body

    assert_match @paquete.cliente.codigo, body, "codigo de cliente completo"
    assert_match @paquete.cliente.nombre_completo.upcase, body.upcase
    assert_match @paquete.tracking, body
    assert_match "RETIRA EN", body, "la sucursal necesita encabezado (el 'San Pedro Soda')"
  end

  test "no lleva terminos y condiciones ni precios" do
    get etiqueta_paquete_url(@paquete)

    assert_no_match(/Terms &amp; Conditions/, response.body)
    assert_no_match(/Declared Value/, response.body)
  end

  test "con hermanas=1 imprime una etiqueta por caja" do
    tracking = "1Z999SPLITETQ"
    3.times do |i|
      Paquete.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                      tracking: tracking, numero_caja: i + 1, cantidad_paquetes: 3,
                      descripcion: "Caja #{i + 1}", user: users(:digitador))
    end
    p1 = Paquete.find_by(tracking: tracking, numero_caja: 1)

    get etiqueta_paquete_url(p1, hermanas: "1")

    assert_response :success
    # "si el tracking se divide en 5 paquetes es una para cada una"
    assert_equal 3, response.body.scan(/class="etq"/).size
    assert_match "1/3", response.body
    assert_match "3/3", response.body
  end

  test "sin hermanas imprime solo la del paquete" do
    get etiqueta_paquete_url(@paquete)

    assert_equal 1, response.body.scan(/class="etq"/).size
  end

  test "el warehouse receipt sigue existiendo aparte" do
    get label_paquete_url(@paquete)

    assert_response :success
    assert_match "WAREHOUSE RECEIPT", response.body
  end
end
