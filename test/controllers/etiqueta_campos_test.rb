require "test_helper"

# PR-10.d: los 11 campos que Yusef anotó en la etiqueta del sistema viejo.
#
# Yusef (2026-08-06) cerró las dos preguntas que quedaban: **no cambia el
# tamaño** de la etiqueta y **van los 11 campos** — "allí es letra pequeña unas
# y otras grandes". La respuesta no era recortar, era graduar el cuerpo de letra.
#
# Este test fija que los 11 salgan. Lo que NO puede verificar es que quepan: el
# recorte lo hace `overflow:hidden` en CSS y ningún test de Rails lo ve. Eso se
# comprueba imprimiendo una.
class EtiquetaCamposTest < ActionDispatch::IntegrationTest
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

  test "la etiqueta lleva los 11 campos" do
    get etiqueta_paquete_url(@paquete)

    assert_response :success
    cuerpo = response.body

    # 1. Código de barras del número de recepción (SVG generado por barby)
    assert_match(/<svg/, cuerpo, "falta el codigo de barras")
    # 2. Número de recepción
    assert_match @paquete.numero_recepcion.presence || @paquete.tracking, cuerpo
    # 3. Tracking original y el secundario
    assert_match @paquete.tracking, cuerpo
    assert_match "TBA999888777", cuerpo
    # 4. Nombre del cliente y del tercero. Van en el HTML tal cual — las
    #    mayúsculas las pone el CSS con `text-transform`.
    assert_match @paquete.cliente.nombre_completo, cuerpo
    assert_match clientes(:maria).nombre_completo.upcase, cuerpo
    # 5. Fecha y hora de recepción
    assert_match(/\d{2}-\w{3}-\d{4}/, cuerpo, "falta la fecha de recepcion")
    # 6. Iniciales de quien registró
    assert_match users(:digitador).iniciales_display, cuerpo
    # 7. Código del cliente, completo
    assert_match @paquete.cliente.codigo, cuerpo
    # 8. Sucursal donde retira, con encabezado en español
    assert_match "RETIRA EN", cuerpo
    # 9. Número y cantidad de paquetes — sale también cuando es una sola caja.
    assert_match ">\n      1/1\n    <", cuerpo, "falta el n/N de paquetes"
    # 10. Tipo de envío
    assert_match @paquete.tipo_envio.codigo.upcase, cuerpo
    # 11. Driver — Yusef lo pidió "por el rótulo"
    assert_match "MARVIN LOPEZ", cuerpo
  end

  test "el tamano de la etiqueta no cambia" do
    # Yusef: "no creo cambiar el tamaño de la etiqueta". Si alguien lo toca,
    # toda la jerarquía de cuerpos de letra deja de cuadrar.
    get etiqueta_paquete_url(@paquete)

    assert_match "2.25in 1.25in", response.body
  end

  test "tercero y driver comparten renglon" do
    # En dos renglones se comian la linea del pie: el presupuesto vertical son
    # 1.15 in y con los 11 campos queda al filo.
    get etiqueta_paquete_url(@paquete)

    tercero_pos = response.body.index("3ro:")
    driver_pos  = response.body.index("Driver:")
    entre_medio = response.body[tercero_pos...driver_pos]

    assert_no_match(/<div/, entre_medio,
                    "tercero y driver no deben abrir divs separados")
  end

  test "sin tercero ni driver la etiqueta igual sale completa" do
    @paquete.update!(tercero: nil, driver: nil)

    get etiqueta_paquete_url(@paquete)

    assert_response :success
    assert_match "RETIRA EN", response.body
    assert_match users(:digitador).iniciales_display, response.body
  end
end
