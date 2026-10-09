# El estilo de los documentos que se le entregan al cliente para revisión.
#
# Vivía suelto en `lib/tasks/docs.rake` como constantes y `def` de nivel de
# archivo. El problema de tenerlo ahí: **un test no lo puede cargar** — Minitest
# no lee los `.rake`, así que los tres PDF que se le mandan a Yusef nunca
# tuvieron ninguna prueba, y un `Prawn::Errors::CannotFit` por anchos de tabla
# mal repartidos solo se descubría corriendo la tarea.
#
# Se usa con `include`: trae los métodos **y** las constantes, así que las
# llamadas de siempre —`h1(pdf, "…")`— siguen escribiéndose igual.
module PdfEntregable
  NAVY = "1B2559".freeze
  GOLD = "E69E2E".freeze
  TEAL = "0096C7".freeze
  GRIS = "6B7280".freeze
  ROJO = "B91C1C".freeze

  # LETTER con márgenes de 45 a los lados: 612 − 45 − 45.
  ANCHO_UTIL = 522

  FUENTES = Rails.root.join("vendor/fonts")

  # Un documento con la fuente ya puesta.
  #
  # El guard no es opcional: sin las TTF, Prawn cae a Helvetica (WinAnsi) y
  # **cada acento del texto en español levanta `IncompatibleStringEncoding`**.
  # Se avisa fuerte en vez de generar un PDF que reviente a la mitad.
  def documento(margen: [ 50, 45, 45, 45 ])
    pdf = Prawn::Document.new(page_size: "LETTER", margin: margen)

    unless File.exist?(FUENTES.join("DejaVuSans.ttf"))
      raise "Falta vendor/fonts/DejaVuSans.ttf — sin esa fuente los acentos revientan"
    end

    pdf.font_families.update("DejaVu" => {
      normal: FUENTES.join("DejaVuSans.ttf").to_s,
      bold: FUENTES.join("DejaVuSans-Bold.ttf").to_s
    })
    pdf.font "DejaVu"
    pdf
  end

  def h1(pdf, texto)
    pdf.move_down 6
    pdf.fill_color NAVY
    pdf.text texto, size: 15, style: :bold
    pdf.fill_color "000000"
    pdf.stroke_color GOLD
    pdf.stroke_horizontal_rule
    pdf.stroke_color "000000"
    pdf.move_down 8
  end

  def h2(pdf, texto)
    pdf.move_down 8
    pdf.fill_color TEAL
    pdf.text texto, size: 11.5, style: :bold
    pdf.fill_color "000000"
    pdf.move_down 4
  end

  def p_(pdf, texto, size: 9.5)
    pdf.text texto, size: size, leading: 2.5, inline_format: true
    pdf.move_down 4
  end

  def cita(pdf, texto)
    pdf.indent(14) do
      pdf.fill_color GRIS
      pdf.text "“#{texto}”", size: 9, leading: 2
      pdf.fill_color "000000"
    end
    pdf.move_down 5
  end

  def tabla(pdf, encabezados, filas, anchos: nil)
    data = [ encabezados ] + filas
    # `width` y `column_widths` juntos chocan si no suman igual; se escala la
    # última columna para que el total dé exactamente el ancho disponible.
    if anchos
      anchos = anchos.dup
      anchos[-1] += pdf.bounds.width - anchos.sum
    end
    opciones = { header: true, cell_style: { size: 8.5, padding: [ 5, 6 ],
                                             border_color: "D4D4D4", inline_format: true } }
    opciones[anchos ? :column_widths : :width] = anchos || pdf.bounds.width

    pdf.table(data, **opciones) do
      row(0).background_color = NAVY
      row(0).text_color = "FFFFFF"
      row(0).font_style = :bold
      rows(1..-1).borders = [ :bottom ]
    end
    pdf.move_down 8
  end

  # Una opción que Yusef marca con una X. El cuadrito va dibujado y no como
  # carácter Unicode: en la impresora de la oficina los glifos de caja salen
  # como rombos negros.
  def opcion(pdf, texto)
    # Si no queda alto para el cuadrito Y su texto, se pasa de página ANTES de
    # dibujar. Sin esto el rectángulo se pinta al final de la hoja y el texto se
    # va a la siguiente: queda un cuadrito huérfano sin nada al lado, y una
    # opción que Yusef no sabe qué está marcando.
    alto_minimo = 26
    pdf.start_new_page if pdf.cursor < alto_minimo

    pdf.move_down 2
    y = pdf.cursor
    pdf.stroke_color GRIS
    pdf.stroke_rectangle [ 4, y ], 9, 9
    pdf.stroke_color "000000"
    pdf.indent(20) { pdf.text texto, size: 9.5, leading: 2, inline_format: true }
    pdf.move_down 2
  end

  # Una línea para escribir a mano la respuesta.
  def linea(pdf, etiqueta = nil)
    pdf.move_down 4
    pdf.fill_color GRIS
    pdf.text "#{etiqueta} #{'.' * 90}"[0, 110], size: 9 if etiqueta
    pdf.text "." * 110, size: 9 unless etiqueta
    pdf.fill_color "000000"
    pdf.move_down 4
  end

  # El bloque de una pregunta: número + título, el cuerpo, y las opciones.
  def pregunta(pdf, numero, titulo)
    # Un título de pregunta solo al pie, con su cuerpo en la hoja siguiente, se
    # lee como si no tuviera contenido. Se necesita lugar para el título más las
    # primeras líneas.
    pdf.start_new_page if pdf.cursor < 90

    pdf.move_down 10
    pdf.fill_color NAVY
    pdf.text "#{numero}. #{titulo}", size: 11, style: :bold
    pdf.fill_color "000000"
    pdf.move_down 4
  end

  # Una tarjeta gris de fondo, para bloques que se leen aparte del cuerpo.
  def tarjeta(pdf, alto, color: "F8F9FB")
    pdf.fill_color color
    pdf.fill_rounded_rectangle([ 0, pdf.cursor ], pdf.bounds.width, alto, 5)
    pdf.fill_color "000000"
  end

  # El pie con la numeración. Va al final, cuando ya existen todas las páginas.
  def numerar(pdf)
    pdf.number_pages "<page> / <total>", at: [ pdf.bounds.right - 60, -22 ], size: 8, color: GRIS
  end
end
