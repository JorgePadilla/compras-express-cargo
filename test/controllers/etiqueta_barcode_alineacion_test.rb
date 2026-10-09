require "test_helper"

# C20-02: el código de barras que la pistola no podía leer.
#
# Yusef, probando la etiqueta impresa con Jorge: *"sí, sí, le cortó la última,
# la derecha… le faltan rayitas"*. Y el diagnóstico es suyo: *"la idea de ese
# margen es que lo corre para la derecha; el problema es que como ya no hay
# espacio, donde lo corre para la derecha **se corta**"*.
#
# El SVG de Barby sale con ancho FIJO en píxeles (211px para un número de
# recepción con sufijo), la etiqueta mide 2.25in y los márgenes le comen
# ancho: lo que sobra lo recorta `overflow:hidden` en silencio. La etiqueta se
# ve bien y no se escanea, y el error aparece recién en San Pedro.
#
# La decisión, de Yusef: *"si lo justificás… se hace un poquito más pequeño el
# código de barra, **pero la pistola lo va a leer**. Eso es lo que hay que
# hacer"*. Code 128 se lee por la proporción entre barras, no por el ancho
# absoluto.
class EtiquetaBarcodeAlineacionTest < ActionDispatch::IntegrationTest
  include EtiquetaHelper

  setup do
    post session_url, params: { email_address: users(:digitador).email_address,
                                password: "password123" }
    @paquete = paquetes(:disponible_entrega_juan)
  end

  test "de fábrica el barcode va justificado, sin ancho fijo que se pueda cortar" do
    get etiqueta_paquete_url(@paquete)

    assert_response :success
    assert_match 'data-alineacion="justificado"', response.body
    tag = svg_del_barcode(response.body)
    assert_match(/width="100%"/, tag, "el ancho fijo en px es lo que se recortaba")
    assert_no_match(/width="\d+px"/, tag)
    # Barby ya los trae; son los que dejan que estirarlo no deforme la lectura.
    assert_match(/viewBox="0 0 \d+ \d+"/, tag)
    assert_match(/preserveAspectRatio="none"/, tag)
  end

  test "justificado no se corta con NINGÚN margen" do
    # El caso de Yusef (2.5mm, el default de C19-06) y el extremo del rango.
    [ "0", "2.5", "10" ].each do |mm|
      Configuracion.set(EtiquetaAjustes::CLAVE_IZQ, mm, tipo: "decimal", categoria: "etiqueta")

      get etiqueta_paquete_url(@paquete)

      assert_match(/width="100%"/, svg_del_barcode(response.body),
                   "con margen #{mm}mm el barcode volvió a tener ancho fijo")
    end
  end

  test "las otras alineaciones conservan el ancho natural y se acomodan" do
    { "izquierda" => "flex-start", "centro" => "center", "derecha" => "flex-end" }.each do |opcion, justify|
      EtiquetaPlantilla.singleton.update!(
        definicion: EtiquetaPlantilla::Definicion.new(
          EtiquetaPlantilla::Definicion::DEFAULT.deep_merge(
            "campos" => { "barcode" => { "alineacion" => opcion } }
          )
        ).normalizada
      )

      get etiqueta_paquete_url(@paquete)

      assert_match "data-alineacion=\"#{opcion}\"", response.body
      assert_match "justify-content:#{justify}", response.body
      assert_match(/width="\d+px"/, svg_del_barcode(response.body),
                   "#{opcion} deja el ancho natural, que es lo que el operario eligió")
    end
  end

  test "una alineación desconocida cae a justificado, no a una etiqueta ilegible" do
    EtiquetaPlantilla.create!(definicion: EtiquetaPlantilla::Definicion::DEFAULT.deep_merge(
      "campos" => { "barcode" => { "alineacion" => "diagonal" } }
    ))

    assert_equal "justificado", EtiquetaPlantilla.vigente.alineacion("barcode")

    get etiqueta_paquete_url(@paquete)
    assert_match 'data-alineacion="justificado"', response.body
  end

  test "guardar la alineación desde el editor la deja aplicada" do
    delete session_url
    post session_url, params: { email_address: users(:admin).email_address,
                                password: "password123" }

    patch plantilla_ajustes_etiqueta_url, params: {
      definicion_json: { campos: { barcode: { alineacion: "centro" } } }.to_json
    }

    assert_equal "centro", EtiquetaPlantilla.vigente.alineacion("barcode")

    get ajustes_etiqueta_url
    assert_match 'value="centro"', response.body
    assert_match "Código de barras", response.body
  end

  private

  # Solo el tag de apertura: adentro van decenas de <rect> con su propio
  # width/height que no se tocan.
  def svg_del_barcode(cuerpo)
    barcode = cuerpo[/data-campo="barcode".*?<svg\b[^>]*>/m]
    assert barcode, "no salió el código de barras"
    barcode[/<svg\b[^>]*>/]
  end
end
