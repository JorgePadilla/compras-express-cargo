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
  include EtiquetaHelper

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
    assert_match ">1/1</span>", cuerpo, "falta el n/N de paquetes"
    # 10. Tipo de envío, abreviado a 3 letras como en el mockup (EXP, no EXPRESS)
    assert_match ">\n          #{@paquete.tipo_envio.codigo.first(3).upcase}\n        <", cuerpo
    # 11. Driver — Yusef lo pidió "por el rótulo"
    assert_match "MARVIN LOPEZ", cuerpo
  end

  test "el tamano de la etiqueta no cambia" do
    # Yusef: "no creo cambiar el tamaño de la etiqueta". Si alguien lo toca,
    # toda la jerarquía de cuerpos de letra deja de cuadrar.
    get etiqueta_paquete_url(@paquete)

    assert_match "2.25in 1.25in", response.body
  end

  test "el tipo de envio se abrevia a tres letras" do
    # En el mockup de Yusef dice EXP, no EXPRESS. No es cosmético: es el texto
    # más grande de la etiqueta, y completo se come más de la mitad del ancho y
    # deja la sucursal truncada en "SAN PED…" — el "¿qué es San Pedro Soda?"
    # que este rediseño vino a arreglar.
    @paquete.update!(tipo_envio: tipo_envios(:express))

    get etiqueta_paquete_url(@paquete)

    assert_match ">\n          EXP\n        <", response.body
    assert_no_match(/>\s*EXPRESS\s*</, response.body)
  end

  test "la sucursal sale completa y con encabezado en espanol" do
    # El campo que provocó el "¿qué es San Pedro Soda?": salía truncado y bajo
    # la palabra inglesa "Agent". El encabezado va en renglón propio para que el
    # nombre tenga todo el ancho de la columna.
    get etiqueta_paquete_url(@paquete)

    assert_match "RETIRA EN", response.body
    assert_match etiqueta_sucursal(@paquete), response.body
  end

  test "sin tercero ni driver la etiqueta igual sale completa" do
    @paquete.update!(tercero: nil, driver: nil)

    get etiqueta_paquete_url(@paquete)

    assert_response :success
    assert_match "RETIRA EN", response.body
    assert_match users(:digitador).iniciales_display, response.body
  end
end
