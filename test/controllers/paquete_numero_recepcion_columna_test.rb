require "test_helper"

# El listado de /paquetes mostraba el tracking DOS VECES seguidas.
#
# Yusef, 2026-08-08, viendo el listado en vivo:
#
#   "Esto está malo... porque te está poniendo el tracking y el número de
#    recepción."
#   "Es que el número de recepción es como el número de registro."
#
# Las columnas "N° recepción" y "Tracking" son vecinas. La primera usaba
# `paquete_display_id`, que cae al tracking cuando no hay recepción — y no la
# hay en la mayoría de los paquetes, porque `generate_numero_recepcion` sale
# temprano cuando el paquete se guarda sin sucursal (`paquete.rb:556`).
#
# Ojo con el diagnóstico: NO es que la recepción esté grabada mal. En la base
# hay cero paquetes con `numero_recepcion = tracking`. Es solo la vista.
# Por eso el arreglo va acá y no en una migración de datos.
#
# El Excel y el PDF del mismo listado ya ponían "—" en ese caso
# (`paquetes_controller.rb:471`, `export.xlsx.axlsx:18`): la pantalla era la
# única que mentía.
class PaqueteNumeroRecepcionColumnaTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @paquete = paquetes(:recibido)
  end

  test "sin numero de recepcion la columna va vacia, no repite el tracking" do
    @paquete.update_columns(numero_recepcion: nil)

    get paquetes_url, params: { q: @paquete.tracking }
    assert_response :success

    celda = columna_recepcion(response.body)
    assert_not_includes celda, @paquete.tracking,
                        "la columna \"N° recepción\" está mostrando el tracking, " \
                        "que ya sale en la columna de al lado"
    assert_includes celda, "—"
  end

  test "con la recepcion GRABADA igual al tracking tampoco la repite" do
    # El otro camino al mismo síntoma, y el que no se puede reproducir en la
    # base local: filas viejas donde la recepción quedó guardada igual al
    # tracking. Jorge en el audio: "estos están hechos porque yo los metí en la
    # base de datos en este formato".
    #
    # Se detecta sin riesgo de falso positivo porque una recepción real es
    # siempre `<PREFIX><AÑO><CORRELATIVO>` y jamás se parece a un tracking.
    @paquete.update_columns(numero_recepcion: @paquete.tracking)

    get paquetes_url, params: { q: @paquete.tracking }
    assert_response :success

    celda = columna_recepcion(response.body)
    assert_not_includes celda, @paquete.tracking
    assert_includes celda, "—"
  end

  test "el PDF del listado tampoco repite el tracking" do
    # Mismo listado, mismas dos columnas vecinas ("N° Recepción" / "Tracking"),
    # mismo fallback. Si se arregla solo la pantalla, el PDF sigue mintiendo.
    @paquete.update_columns(numero_recepcion: nil)

    fila = Paquetes::ListadoPdf.new([ @paquete ]).send(:row_for, @paquete)

    recepcion, tracking = fila[2], fila[3]
    assert_not_equal tracking, recepcion,
                     "el PDF imprime el tracking en la columna de recepción"
    assert_equal "—", recepcion
  end

  test "con numero de recepcion la columna lo muestra" do
    @paquete.update_columns(numero_recepcion: "RM0002026000042")

    get paquetes_url, params: { q: @paquete.tracking }
    assert_response :success

    assert_includes columna_recepcion(response.body), "RM0002026000042"
  end

  test "las dos columnas vecinas no muestran el mismo texto" do
    # El síntoma tal como lo vio Yusef: el mismo número dos veces seguidas.
    #
    # Se compara el TEXTO VISIBLE de las dos celdas, no el HTML: el tracking
    # aparece de todos modos siete veces en la fila (en `data-tracking`, en el
    # href, en el confirm de borrar, en tooltips), y nada de eso se ve.
    @paquete.update_columns(numero_recepcion: nil, tracking_secundario: nil)

    get paquetes_url, params: { q: @paquete.tracking }
    assert_response :success

    recepcion = texto(columna_recepcion(response.body))
    tracking  = texto(columna_tracking(response.body))

    assert tracking.present?, "no se encontró la columna de tracking"
    assert_not_equal tracking, recepcion,
                     "\"N° recepción\" y \"Tracking\" muestran lo mismo: #{recepcion.inspect}"
  end

  private

  # Lee las celdas por `data-campo` en vez de por posición: el listado tiene 17
  # columnas y se reordenan seguido.
  def columna_recepcion(cuerpo)
    cuerpo[/<td[^>]*data-campo="numero-recepcion"[^>]*>(.*?)<\/td>/m, 1].to_s
  end

  def columna_tracking(cuerpo)
    cuerpo[/<td[^>]*data-campo="tracking"[^>]*>(.*?)<\/td>/m, 1].to_s
  end

  def texto(html)
    html.gsub(/<[^>]*>/, " ").squish
  end
end
