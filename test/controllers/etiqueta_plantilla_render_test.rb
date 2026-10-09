require "test_helper"

# C19-06: la etiqueta se renderiza desde la plantilla (EtiquetaPlantilla).
# Sin registro rige la de fábrica — que tiene que ser la etiqueta de hoy 1:1
# (eso lo fijan los tests de siempre, que corren sin registro). Acá se fija lo
# nuevo: que una plantilla guardada mande, y que la basura caiga al default.
class EtiquetaPlantillaRenderTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:digitador).email_address,
                                password: "password123" }
    @paquete = paquetes(:disponible_entrega_juan)
    @paquete.update!(
      tracking_secundario: "TBA999888777",
      driver: "Marvin Lopez",
      tercero: clientes(:maria)
    )
  end

  test "con el default salen todos los data-campo" do
    get etiqueta_paquete_url(@paquete)

    assert_response :success
    %w[barcode numero-recepcion tracking tracking-secundario tercero fecha
       driver reg cliente-codigo sucursal ubicacion proveedor tipo-envio].each do |campo|
      assert_match "data-campo=\"#{campo}\"", response.body, "falta #{campo}"
    end
    # Y las vars de tamaño de fábrica, pt × escala 100.
    assert_match "--fs-tipo-envio: 19pt;", response.body
    assert_match "--fs-tracking: 7pt;", response.body
    assert_match "--fs-sucursal-rotulo: 6pt;", response.body
    assert_match "2.25in 1.25in", response.body
  end

  test "una plantilla guardada manda sobre tamaños, escala y dimensiones" do
    EtiquetaPlantilla.create!(definicion: EtiquetaPlantilla::Definicion::DEFAULT.deep_merge(
      "escala_pct" => 110,
      "dim" => { "ancho_in" => 3.0, "alto_in" => 2.0 },
      "campos" => { "tipo_envio" => { "pt" => 25.0 }, "sucursal" => { "texto" => "AGENCIA" } }
    ))

    get etiqueta_paquete_url(@paquete)

    assert_match "--fs-tipo-envio: 27.5pt;", response.body   # 25 × 1.10
    assert_match "--fs-tracking: 7.7pt;", response.body      # 7 × 1.10
    assert_match "size: 3in 2in", response.body
    assert_match "AGENCIA", response.body
    assert_no_match(/RETIRA EN/, response.body)
  end

  test "una plantilla con basura imprime la de fábrica, no basura" do
    EtiquetaPlantilla.create!(definicion: { "version" => 1, "escala_pct" => 900,
                                            "campos" => { "tipo_envio" => { "pt" => 99 } } })

    get etiqueta_paquete_url(@paquete)

    assert_response :success
    assert_match "--fs-tipo-envio: 19pt;", response.body
    assert_match "2.25in 1.25in", response.body
  end

  test "las combinadas del split también rinden por la plantilla" do
    EtiquetaPlantilla.create!(definicion: EtiquetaPlantilla::Definicion::DEFAULT.deep_merge(
      "campos" => { "tipo_envio" => { "pt" => 21.0 } }
    ))
    cajas = (1..2).map do |i|
      Paquete.create!(
        tracking: @paquete.tracking, guia: "PLA-#{i}-#{SecureRandom.hex(3)}",
        cliente: @paquete.cliente, tipo_envio: @paquete.tipo_envio,
        estado: @paquete.estado, peso: 5, peso_cobrar: 5,
        cantidad_productos: 1, cantidad_paquetes: 2, numero_caja: i,
        descripcion: "Caja #{i}", user: users(:digitador)
      )
    end

    get etiquetas_combinadas_paquetes_url(paquete_ids: cajas.map(&:id))

    assert_response :success
    assert_match "--fs-tipo-envio: 21pt;", response.body
    assert_equal 2, response.body.scan('data-campo="tipo-envio"').size
  end
end
