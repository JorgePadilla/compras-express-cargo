require "test_helper"

# C19-06 · PR-C7.64: guardar/restaurar la plantilla y el preview en vivo.
# La regla madre en acción: lo que se persiste ya pasó por los clamps — el
# path de impresión nunca depende de que el editor se haya portado bien.
class AjustesEtiquetaPlantillaTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: {
      email_address: users(:admin).email_address, password: "password123"
    }
  end

  test "el show trae el editor con el preview" do
    get ajustes_etiqueta_url
    assert_response :success
    assert_match "Vista previa", response.body
    assert_match "Escala de toda la letra", response.body
    assert_match "Tamaño de letra por campo", response.body
    assert_match "data-def-path=\"campos.tipo_envio.pt\"", response.body
  end

  test "guardar clampa: la basura no llega a la base" do
    patch plantilla_ajustes_etiqueta_url, params: {
      definicion_json: { escala_pct: 900,
                         dim: { ancho_in: 12, alto_in: 1.25 },
                         campos: { tipo_envio: { pt: 99 }, tracking: { pt: 8.0 } } }.to_json
    }

    assert_redirected_to ajustes_etiqueta_url
    d = EtiquetaPlantilla.vigente
    assert_equal 100, d.escala_pct
    assert_equal 2.25, d.ancho_in
    assert_equal 19.0, d.pt("tipo_envio"), "99pt tenía que caer al default"
    assert_equal 8.0, d.pt("tracking"), "el valor válido sí rige"
  end

  test "un JSON roto no guarda nada" do
    assert_no_difference "EtiquetaPlantilla.count" do
      patch plantilla_ajustes_etiqueta_url, params: { definicion_json: "{roto" }
    end
    assert_redirected_to ajustes_etiqueta_url
    assert_match(/no se guardó/i, flash[:alert])
  end

  test "el preview renderiza la candidata sin persistir nada" do
    assert_no_difference [ "EtiquetaPlantilla.count", "Paquete.count" ] do
      post preview_ajustes_etiqueta_url, params: {
        definicion_json: { escala_pct: 110 }.to_json
      }
    end

    assert_response :success
    assert_match 'class="etq"', response.body
    assert_match "--fs-tipo-envio: 20.9pt;", response.body   # 19 × 1.10
    # La muestra viene llena: la etiqueta que puede no caber es la llena.
    assert_match "TBA333187639911", response.body
    assert_match 'data-campo="tracking-secundario"', response.body
    assert_match 'data-campo="tercero"', response.body
  end

  test "restaurar borra la personalización y vuelve la de fábrica" do
    EtiquetaPlantilla.create!(definicion: EtiquetaPlantilla::Definicion::DEFAULT.deep_merge(
      "campos" => { "tipo_envio" => { "pt" => 25.0 } }
    ))

    delete plantilla_ajustes_etiqueta_url

    assert_redirected_to ajustes_etiqueta_url
    assert_equal 0, EtiquetaPlantilla.count
    assert_equal 19.0, EtiquetaPlantilla.vigente.pt("tipo_envio")
  end

  # PR-C7.65: on/off y textos fijos, de punta a punta por el flujo real.
  test "apagar un campo lo saca de la etiqueta; la identidad no se apaga" do
    patch plantilla_ajustes_etiqueta_url, params: {
      definicion_json: { campos: { tercero: { visible: false },
                                   ubicacion: { visible: false },
                                   tracking: { visible: false },
                                   barcode: { visible: false } } }.to_json
    }

    paquete = paquetes(:disponible_entrega_juan)
    paquete.update!(tercero: clientes(:maria), tracking_secundario: "TBA999888777")
    get etiqueta_paquete_url(paquete)

    assert_response :success
    assert_no_match(/data-campo="tercero"/, response.body, "tercero quedó apagado")
    assert_no_match(/data-campo="ubicacion"/, response.body)
    assert_match 'data-campo="tracking"', response.body, "el tracking no se apaga ni pidiéndolo"
    assert_match 'data-campo="barcode"', response.body, "el barcode tampoco"
  end

  test "el texto fijo cambiado sale; vacío o larguísimo vuelve al de fábrica" do
    patch plantilla_ajustes_etiqueta_url, params: {
      definicion_json: { campos: { sucursal: { texto: "AGENCIA" },
                                   reg: { texto: "" },
                                   driver: { texto: "x" * 30 } } }.to_json
    }

    paquete = paquetes(:disponible_entrega_juan)
    paquete.update!(driver: "Marvin Lopez")
    get etiqueta_paquete_url(paquete)

    assert_match "AGENCIA", response.body
    assert_no_match(/RETIRA EN/, response.body)
    assert_match "Reg: <b", response.body, "el texto vacío volvió al de fábrica"
    assert_match "Drv: <b>ML</b>", response.body, "el texto pasado de largo también"
  end

  test "non-admin no toca la plantilla" do
    delete session_url
    post session_url, params: {
      email_address: users(:digitador).email_address, password: "password123"
    }

    patch plantilla_ajustes_etiqueta_url, params: { definicion_json: "{}" }
    assert_redirected_to root_path
    post preview_ajustes_etiqueta_url, params: { definicion_json: "{}" }
    assert_redirected_to root_path
    delete plantilla_ajustes_etiqueta_url
    assert_redirected_to root_path
  end
end
