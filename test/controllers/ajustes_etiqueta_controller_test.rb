require "test_helper"

# C19-06. Yusef: "¿vos no tenés en el sistema donde yo pueda cambiarlas yo?…
# con eso yo te quito a vos". Los márgenes horizontales de la etiqueta salen
# de Configuracion y se ajustan desde /ajustes_etiqueta, solo admin — patrón
# calcado de /tasa_cambio.
class AjustesEtiquetaControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: {
      email_address: users(:admin).email_address, password: "password123"
    }
  end

  test "show responde 200 para admin" do
    get ajustes_etiqueta_url
    assert_response :success
    assert_match(/margen izquierdo/i, response.body)
  end

  test "non-admin queda redirigido" do
    delete session_url
    post session_url, params: {
      email_address: users(:digitador).email_address, password: "password123"
    }
    get ajustes_etiqueta_url
    assert_redirected_to root_path
  end

  test "guardar persiste las dos claves" do
    patch ajustes_etiqueta_url, params: { margen_izq_mm: "3.5", margen_der_mm: "1,5" }

    assert_redirected_to ajustes_etiqueta_url
    assert_equal "3.5", Configuracion.get(EtiquetaAjustes::CLAVE_IZQ)
    # La coma también vale — es como teclean acá.
    assert_equal "1.5", Configuracion.get(EtiquetaAjustes::CLAVE_DER)
  end

  test "un valor fuera de rango no se guarda" do
    # 25mm en una etiqueta de 57mm dejaría los trackings sin lugar — y "LOS
    # TRACKING DEBEN CABER COMPLETOS" es regla escrita de Yusef.
    patch ajustes_etiqueta_url, params: { margen_izq_mm: "25", margen_der_mm: "1.5" }

    assert_redirected_to ajustes_etiqueta_url
    assert_nil Configuracion.get(EtiquetaAjustes::CLAVE_IZQ)
  end

  test "la etiqueta imprime con los margenes configurados" do
    Configuracion.set(EtiquetaAjustes::CLAVE_IZQ, "4.0", tipo: "decimal", categoria: "etiqueta")
    Configuracion.set(EtiquetaAjustes::CLAVE_DER, "2.0", tipo: "decimal", categoria: "etiqueta")

    get etiqueta_paquete_url(paquetes(:disponible_entrega_juan))
    assert_response :success
    assert_match(/padding:\s*0\.04in 2\.0mm 0\.04in 4\.0mm/, response.body)
  end

  test "sin configuracion, la etiqueta sale con el default corrido a la derecha" do
    get etiqueta_paquete_url(paquetes(:disponible_entrega_juan))
    assert_response :success
    # Izquierdo 2.5mm (corrido), derecho 1.5mm ("el lado derecho déjalo tal cual").
    assert_match(/padding:\s*0\.04in 1\.5mm 0\.04in 2\.5mm/, response.body)
  end

  test "un valor basura en la base cae al default, no a la impresora" do
    Configuracion.set(EtiquetaAjustes::CLAVE_IZQ, "999", tipo: "decimal", categoria: "etiqueta")

    get etiqueta_paquete_url(paquetes(:disponible_entrega_juan))
    assert_match(/padding:\s*0\.04in 1\.5mm 0\.04in 2\.5mm/, response.body)
  end
end
