require Rails.root.join("lib/pdf_entregable")

# Cajas, flechas y rombos para dibujar un proceso en un PDF.
#
# En este repo nadie había dibujado un diagrama en Prawn: `stroke_line` y
# `fill_polygon` no aparecían en ningún lado. Todo el vocabulario de formas que
# existía eran el cuadrito de la casilla y una tarjeta redondeada.
#
# ── Las coordenadas ───────────────────────────────────────────────────────
#
# Prawn cuenta desde abajo a la izquierda, y las formas se posicionan por su
# esquina **superior** izquierda. Acá todo se maneja igual: `y` es el borde de
# arriba, y una caja de alto 40 ocupa de `y` a `y - 40`.
#
# Cada forma devuelve sus puntos de conexión —`{ arriba:, abajo:, izq:, der: }`—
# para que `flecha` reciba dos puntos y no haya que calcularlos a mano en cada
# página. Eso es lo que evita las flechas que no llegan a la caja.
module PdfDiagrama
  include PdfEntregable

  ALTO_CAJA = 46
  RADIO = 4

  # Un paso que ya existe: borde sólido navy.
  #
  # `quien` va adentro, chiquito: en un diagrama de proceso la pregunta que más
  # se hace es "¿y esto quién lo hace?".
  def caja(pdf, x, y, ancho, titulo:, quien: nil, alto: ALTO_CAJA, color: NAVY, relleno: nil)
    if relleno
      pdf.fill_color relleno
      pdf.fill_rounded_rectangle([ x, y ], ancho, alto, RADIO)
      pdf.fill_color "000000"
    end

    pdf.stroke_color color
    pdf.line_width 1.2
    pdf.stroke_rounded_rectangle([ x, y ], ancho, alto, RADIO)
    pdf.line_width 1
    pdf.stroke_color "000000"

    texto_de_caja(pdf, x, y, ancho, alto, titulo, quien, color)
    conexiones(x, y, ancho, alto)
  end

  # Un paso que NO existe todavía: borde punteado y gris.
  #
  # La diferencia tiene que verse **impresa en blanco y negro**, así que no
  # alcanza con cambiar el color: el trazo punteado es lo que la hace legible en
  # una fotocopia.
  def caja_pendiente(pdf, x, y, ancho, titulo:, quien: nil, alto: ALTO_CAJA)
    pdf.stroke_color GRIS
    pdf.line_width 1
    pdf.dash(3, space: 2)
    pdf.stroke_rounded_rectangle([ x, y ], ancho, alto, RADIO)
    pdf.undash
    pdf.stroke_color "000000"

    texto_de_caja(pdf, x, y, ancho, alto, titulo, quien, GRIS)
    conexiones(x, y, ancho, alto)
  end

  # Un rombo de decisión. `ancho`/`alto` son los de su caja envolvente.
  #
  # El texto va en la MITAD del ancho, no en todo: un rombo se angosta hacia
  # arriba y hacia abajo, así que una línea que ocupe el ancho completo se sale
  # por los dos lados apenas pasa de un renglón. Con la mitad entran dos
  # renglones sin tocar el borde.
  def rombo(pdf, x, y, ancho, pregunta:, alto: 64)
    cx = x + ancho / 2.0
    cy = y - alto / 2.0
    ancho_texto = ancho * 0.52

    pdf.stroke_color NAVY
    pdf.line_width 1.2
    pdf.stroke_polygon([ cx, y ], [ x + ancho, cy ], [ cx, y - alto ], [ x, cy ])
    pdf.line_width 1
    pdf.stroke_color "000000"

    pdf.fill_color NAVY
    pdf.text_box pregunta, at: [ cx - ancho_texto / 2, y - 6 ], width: ancho_texto, height: alto - 12,
                           size: 7.5, align: :center, valign: :center, style: :bold,
                           overflow: :shrink_to_fit
    pdf.fill_color "000000"

    conexiones(x, y, ancho, alto)
  end

  # Una flecha entre dos puntos. Solo ortogonal —recta, o con UN codo— porque
  # una diagonal en un diagrama de proceso se lee peor.
  #
  # `etiqueta` es el "sí"/"no" de una decisión: va pegada al primer tramo.
  def flecha(pdf, desde, hasta, etiqueta: nil, color: NAVY)
    pdf.stroke_color color
    pdf.fill_color color
    pdf.line_width 1

    x1, y1 = desde
    x2, y2 = hasta

    if (x1 - x2).abs < 0.5 || (y1 - y2).abs < 0.5
      pdf.stroke_line desde, hasta
    else
      # El codo: primero vertical, después horizontal. Salvo que arranque
      # horizontal, y ahí al revés.
      codo = (y1 - y2).abs > (x1 - x2).abs ? [ x1, y2 ] : [ x2, y1 ]
      pdf.stroke_line desde, codo
      pdf.stroke_line codo, hasta
    end

    punta(pdf, desde, hasta)

    if etiqueta
      pdf.fill_color GRIS
      pdf.text_box etiqueta, at: [ x1 + 4, y1 - 2 ], width: 60, height: 12, size: 7
      pdf.fill_color color
    end

    pdf.fill_color "000000"
    pdf.stroke_color "000000"
  end

  # Una caja de la que salen varias, lado a lado. Para lo que se bifurca:
  # un paquete que sale del camino se retorna **o** se desecha **o** se anula,
  # nunca las tres. Dibujarlas en cadena sería decirle a Yusef que el proceso
  # hace algo que no hace.
  #
  # `ramas` se reparten el ancho útil; el tronco va centrado arriba.
  def abanico(pdf, ramas, y:, alto: ALTO_CAJA, separacion: 22, ancho_maximo: 210)
    ancho = [ (ANCHO_UTIL - separacion * (ramas.size - 1)) / ramas.size.to_f, ancho_maximo ].min
    total = ancho * ramas.size + separacion * (ramas.size - 1)
    x0 = (ANCHO_UTIL - total) / 2.0

    ramas.each_with_index.map { |dibujar, i| dibujar.call(x0 + i * (ancho + separacion), y, ancho, alto) }
  end

  # El conector del abanico: baja del tronco, se abre en horizontal, y de ahí
  # cae una flecha a cada rama. Un codo por rama se leería como una diagonal
  # cruzada; la barra común deja ver de un vistazo que son alternativas.
  def bifurcar(pdf, tronco, ramas, color: NAVY)
    y_barra = ramas.first[:y] + 20

    pdf.stroke_color color
    pdf.line_width 1
    pdf.stroke_line tronco[:abajo], [ tronco[:abajo][0], y_barra ]
    pdf.stroke_line [ ramas.first[:arriba][0], y_barra ], [ ramas.last[:arriba][0], y_barra ]
    pdf.stroke_color "000000"

    ramas.each { |r| flecha(pdf, [ r[:arriba][0], y_barra ], r[:arriba], color: color) }
  end

  # La banda que agrupa un tramo del proceso: "En Miami", "En Honduras".
  def carril(pdf, y, alto, titulo:, color: TEAL)
    pdf.fill_color color
    pdf.fill_rectangle [ 0, y ], 3, alto
    pdf.text_box titulo.upcase, at: [ 10, y ], width: 200, height: 12, size: 8, style: :bold
    pdf.fill_color "000000"
  end

  # Una nota al costado de una caja. Para lo que hay que explicar sin meterlo
  # adentro del dibujo.
  def nota(pdf, x, y, texto, ancho: 150, color: GRIS)
    pdf.fill_color color
    pdf.text_box texto, at: [ x, y ], width: ancho, height: 60, size: 7, leading: 1.5
    pdf.fill_color "000000"
  end

  # La leyenda. Es la parte más importante del documento: sin esto, una caja
  # punteada es solo una caja fea.
  def leyenda(pdf, y)
    caja(pdf, 0, y, 150, titulo: "Un paso que ya existe", quien: "quién lo hace")
    caja_pendiente(pdf, 186, y, 150, titulo: "Un paso que falta", quien: "todavía no hay pantalla")
    rombo(pdf, 372, y, 150, pregunta: "Una decisión")
    y - 70
  end

  private

  def texto_de_caja(pdf, x, y, ancho, alto, titulo, quien, color)
    pdf.fill_color color
    alto_titulo = quien ? 20 : alto - 12
    pdf.text_box titulo, at: [ x + 8, y - 9 ], width: ancho - 16, height: alto_titulo,
                         size: 9, style: :bold, align: :center, overflow: :shrink_to_fit

    if quien
      pdf.fill_color GRIS
      pdf.text_box quien, at: [ x + 8, y - 28 ], width: ancho - 16, height: 16,
                          size: 6.5, align: :center, overflow: :shrink_to_fit
    end
    pdf.fill_color "000000"
  end

  def conexiones(x, y, ancho, alto)
    {
      arriba: [ x + ancho / 2.0, y ],
      abajo:  [ x + ancho / 2.0, y - alto ],
      izq:    [ x, y - alto / 2.0 ],
      der:    [ x + ancho, y - alto / 2.0 ],
      x: x, y: y, ancho: ancho, alto: alto
    }
  end

  # El triangulito del final. Se orienta según de dónde viene el último tramo.
  def punta(pdf, desde, hasta)
    x1, y1 = desde
    x2, y2 = hasta
    lado = 4

    # El último tramo de un codo puede ser horizontal aunque el trazo arranque
    # vertical, así que la orientación se decide con el codo, no con el origen.
    codo = if (x1 - x2).abs < 0.5 || (y1 - y2).abs < 0.5
      desde
    else
      (y1 - y2).abs > (x1 - x2).abs ? [ x1, y2 ] : [ x2, y1 ]
    end

    if (codo[1] - y2).abs < 0.5
      dir = x2 > codo[0] ? 1 : -1
      pdf.fill_polygon([ x2, y2 ], [ x2 - dir * lado * 1.6, y2 + lado ], [ x2 - dir * lado * 1.6, y2 - lado ])
    else
      dir = y2 > codo[1] ? 1 : -1
      pdf.fill_polygon([ x2, y2 ], [ x2 - lado, y2 - dir * lado * 1.6 ], [ x2 + lado, y2 - dir * lado * 1.6 ])
    end
  end
end
