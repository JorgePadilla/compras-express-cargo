require Rails.root.join("lib/pdf_entregable")

# El PDF de los servicios, para que Yusef lo revise a mano.
#
# El precedente es `docs:preguntas_pdf`: ese cuestionario Yusef lo imprimió, lo
# contestó con lapicero y lo devolvió — de ahí salieron `RP-01`…`RP-23`. Así que
# esto no es un documento para leer, es **un papel para escribirle encima**, y
# por eso las casillas van dibujadas con `stroke_rectangle`: los glifos Unicode
# de caja salen como rombos negros en la impresora de la oficina.
#
# ── Los datos salen de la BASE, no de acá ─────────────────────────────────
#
# La gracia del documento es mostrar **lo que el sistema cobra hoy**, para
# poder contrastarlo con lo que Yusef cree que cobra. Hardcodear los precios lo
# convertiría en otra copia de la documentación — que es justo la que no
# coincide.
class ServiciosPdf
  include PdfEntregable

  # Los cinco de verdad. Se eligen por código y no con `TipoEnvio.activos`
  # porque en la base sobreviven "CER Legacy" y "CEM Legacy" —que `seeds.rb`
  # dice desactivar y no tienen ninguna tarifa—, y meterlos en el PDF sería
  # ruido para el que lo lee. Que sobrevivan sale como aviso en la consola.
  CANONICOS = %w[express cer cem cka ckm].freeze

  DESCRIPCIONES = {
    "express" => "Express aéreo — el más rápido, con reempaque",
    "cer"     => "Carga Express Aéreo — con reempaque",
    "cem"     => "Carga Express Marítimo — con reempaque",
    "cka"     => "Carga Kilo Aéreo — sin reempaque",
    "ckm"     => "Carga Kilo Marítimo — sin reempaque"
  }.freeze

  # La segunda línea de la dirección de Miami cambia por servicio, y es la que
  # el cliente escribe mal.
  LINEA_2 = {
    "express" => "EXPRESS",
    "cer"     => "REEMPAQUE AEREO",
    "cem"     => "REEMPAQUE MARITIMO",
    "cka"     => "AEREO CKA",
    "ckm"     => "MARITIMO CKM"
  }.freeze

  DIRECCION_1 = "8109 NW 60th ST, Miami, FL 33195-3415".freeze
  TELEFONO = "305-848-0990".freeze

  ISV = BigDecimal("0.15")

  # La base las guarda sin acento; en el documento van bien escritas.
  MODALIDADES = { "aereo" => "Aéreo", "maritimo" => "Marítimo" }.freeze

  # ── Los datos ───────────────────────────────────────────────────────────
  # Métodos puros, sin Prawn: son los que se pueden probar.

  def servicios
    @servicios ||= begin
      por_codigo = TipoEnvio.where(codigo: CANONICOS).index_by(&:codigo)
      CANONICOS.filter_map { |c| por_codigo[c] }
    end
  end

  # La escalera de precios de LISTA: sin cliente, sin proveedor, sin categoría.
  # Es el precio público — el que Yusef puede confirmar sin mirar a quién se le
  # cobra.
  def escalera(tipo)
    Tarifa.where(tipo_envio_id: tipo.id, activo: true,
                 cliente_id: nil, proveedor_id: nil, categoria_precio_id: nil,
                 sucursal_id: nil)
          .order(:desde_libras)
          .map do |t|
            { desde: t.desde_libras.to_f, hasta: t.hasta_libras&.to_f,
              precio: t.precio_libra.to_f, moneda: t.moneda }
          end
  end

  def minimo(tipo)
    fila = Tarifa.where(tipo_envio_id: tipo.id, activo: true,
                        cliente_id: nil, proveedor_id: nil, categoria_precio_id: nil)
                 .where.not(minimo_monto: nil).first
    return nil if fila.nil?

    monto = fila.minimo_monto.to_d
    { monto: monto, moneda: fila.minimo_moneda || fila.moneda,
      con_isv: (monto * (1 + ISV)).round(2) }
  end

  def hechos(tipo)
    {
      modalidad: MODALIDADES.fetch(tipo.modalidad.to_s, tipo.modalidad.to_s.capitalize),
      sla: sla_bonito(tipo),
      reempaque: tipo.con_reempaque?,
      consolidable: tipo.consolidable?,
      max_paquetes: tipo.max_paquetes_por_accion || "sin límite"
    }
  end

  def direccion(tipo)
    { linea1: DIRECCION_1, linea2: LINEA_2[tipo.codigo], telefono: TELEFONO }
  end

  # Los problemas de datos que encuentre. Van a la CONSOLA, no al PDF: son para
  # quien genera el documento, no para quien lo revisa.
  def avisos(ids_de_sucursales = Sucursal.pluck(:id))
    lista = []

    faltantes = CANONICOS - servicios.map(&:codigo)
    lista << "servicios canónicos que no existen en la base: #{faltantes.join(', ')}" if faltantes.any?

    servicios.each do |t|
      lista << "#{t.nombre} no tiene tarifa de lista — el PDF va a salir sin su escalera" if escalera(t).empty?
      lista << "#{t.nombre} no tiene mínimo cargado" if minimo(t).nil?
    end

    sobrantes = TipoEnvio.activos.reject { |t| CANONICOS.include?(t.codigo) }
    if sobrantes.any?
      lista << "servicios activos que NO son de los cinco: #{sobrantes.map(&:nombre).join(', ')} " \
               "(seeds.rb dice desactivarlos)"
    end

    lista.concat(tarifas_huerfanas(ids_de_sucursales))
    lista
  end

  # Tarifas que apuntan a una sucursal que ya no existe.
  #
  # Hay una FK sobre `tarifas.sucursal_id`, así que **por la aplicación esto no
  # puede pasar**. Sí pasa cargando fixtures: `disable_referential_integrity`
  # deja reemplazar las sucursales por otras con ids nuevos y las tarifas quedan
  # apuntando al vacío. En la base de desarrollo hay tres así.
  #
  # Y no es cosmético: `Tarifa.resolver` busca `find_by(sucursal_id: …)`, no
  # encuentra, y cae a la fila genérica. O sea que el recargo por sucursal
  # cargado contra un id viejo **no se cobra nunca**, en silencio.
  # `ids_reales` es un parámetro para poder probarlo: la fila huérfana no se
  # puede crear de verdad —la FK lo impide— así que el test simula que la
  # sucursal desapareció, que es justo lo que pasó cargando fixtures.
  def tarifas_huerfanas(ids_reales = Sucursal.pluck(:id))
    huerfanas = Tarifa.where.not(sucursal_id: nil).where.not(sucursal_id: ids_reales)
    return [] if huerfanas.empty?

    filas = huerfanas.includes(:tipo_envio).map do |t|
      "tarifa de #{t.tipo_envio&.nombre} (desde #{t.desde_libras.to_f} lb, $#{t.precio_libra.to_f}) " \
        "apunta a sucursal_id=#{t.sucursal_id}, que no existe — ese precio NUNCA se aplica"
    end

    # El diagnóstico va en el aviso y no solo en este comentario: escrito
    # únicamente acá arriba, el que corre la tarea lee "un precio no se cobra
    # nunca" y sale a buscar un bug de plata. Pasó dos veces, la segunda a mí.
    filas << PISTA_DE_FIXTURES
  end

  PISTA_DE_FIXTURES =
    "↑ antes de salir a buscar: si esto aparece en tu máquina, casi seguro " \
    "cargaste los fixtures de test en la base de desarrollo — reemplazan las " \
    "sucursales por otras con ids distintos y dejan las tarifas apuntando al " \
    "vacío. La FK impide que pase en staging. Confirmalo con `bin/rails db:reset`."

  # ── El documento ────────────────────────────────────────────────────────

  def render
    construir.render
  end

  def render_file(ruta)
    construir.render_file(ruta)
  end

  private

  # Paginar es decisión del documento, no de cada sección. Con el
  # `start_new_page` adentro de cada una, la primera página salía en blanco y
  # ninguna sección se podía renderizar sola para mirarla — que es lo único que
  # sirve para revisar un PDF, porque no hay preview.
  def construir
    pdf = documento

    secciones = [ method(:portada), method(:comparativa) ]
    secciones += servicios.map { |t| ->(doc) { ficha(doc, t) } }
    secciones += [ method(:cadena_de_cobro), method(:viaje_del_paquete) ]

    secciones.each_with_index do |seccion, i|
      pdf.start_new_page unless i.zero?
      seccion.call(pdf)
    end

    numerar(pdf)
    pdf
  end

  def portada(pdf)
    pdf.fill_color NAVY
    pdf.text "Compras Express Cargo", size: 24, style: :bold
    pdf.fill_color GOLD
    pdf.text "Los servicios, para revisar", size: 15, style: :bold
    pdf.fill_color GRIS
    pdf.text "Lo que el sistema cobra hoy  ·  #{fecha_larga}", size: 9.5
    pdf.fill_color "000000"
    pdf.move_down 16

    tarjeta(pdf, 86)
    pdf.move_down 12
    pdf.indent(14) do
      p_(pdf, "<b>Cómo contestar:</b> marcá la casilla con una X y escribí en los renglones. " \
              "Si ninguna opción sirve, usá <b>Otro</b>. Cuando termines, mandá la foto de las " \
              "hojas que hayas marcado — no hace falta devolver todo.", size: 9.5)
      p_(pdf, "Los números de este documento salen del sistema, no de la documentación. " \
              "Donde los dos no coinciden, aparece la pregunta.", size: 9.5)
    end
    pdf.move_down 20

    h2(pdf, "Qué hay adentro")
    tabla(pdf, [ "Página", "Qué es" ], [
      [ "2", "Los cinco servicios lado a lado — la hoja para pegar en la pared" ],
      [ "3 – 7", "Una ficha por servicio: precios, mínimo y dirección de Miami" ],
      [ "8", "Cómo se calcula lo que se cobra, paso a paso, con un ejemplo" ],
      [ "9", "Por dónde pasa un paquete y quién lo mueve" ]
    ], anchos: [ 70, 452 ])
  end

  def comparativa(pdf)
    h1(pdf, "Los cinco servicios, lado a lado")

    filas = [
      [ "Modalidad", *servicios.map { |t| hechos(t)[:modalidad] } ],
      [ "Tiempo", *servicios.map { |t| sla_bonito(t) } ],
      [ "Reempaque", *servicios.map { |t| si_no(t.con_reempaque?) } ],
      [ "Consolidable", *servicios.map { |t| si_no(t.consolidable?) } ],
      [ "Máx. paquetes", *servicios.map { |t| t.max_paquetes_por_accion&.to_s || "sin límite" } ],
      [ "Precio por libra", *servicios.map { |t| precio_entrada_texto(t) } ],
      [ "Baja hasta", *servicios.map { |t| precio_piso_texto(t) } ],
      [ "Escalonado", *servicios.map { |t| tramos_texto(t) } ],
      [ "Cobro mínimo", *servicios.map { |t| minimo_corto(t) } ]
    ]

    tabla(pdf, [ "", *servicios.map(&:nombre) ], filas, anchos: [ 122, 80, 80, 80, 80, 80 ])

    p_(pdf, "<b>Reempaque</b> es sacar el producto de su caja original y empacarlo de nuevo. " \
            "<b>Consolidable</b> quiere decir que varios paquetes pueden viajar como uno.")
    p_(pdf, "Los precios están en dólares y la factura sale en lempiras: se convierten a la " \
            "tasa que fija un administrador en el sistema.")
  end

  def ficha(pdf, tipo)
    # Encabezado con el nombre sobre navy.
    pdf.fill_color NAVY
    pdf.fill_rounded_rectangle([ 0, pdf.cursor ], pdf.bounds.width, 46, 5)
    pdf.fill_color "FFFFFF"
    pdf.move_down 12
    pdf.indent(14) do
      pdf.text tipo.nombre, size: 17, style: :bold
      pdf.text DESCRIPCIONES[tipo.codigo].to_s, size: 9.5
    end
    pdf.fill_color "000000"
    pdf.move_down 22

    h = hechos(tipo)
    tabla(pdf, [ "Modalidad", "Tiempo", "Reempaque", "Consolidable", "Máx. paquetes" ], [
      [ h[:modalidad], sla_bonito(tipo),
        si_no(h[:reempaque]), si_no(h[:consolidable]), h[:max_paquetes].to_s ]
    ], anchos: [ 104, 104, 104, 104, 106 ])

    escalera_dibujada(pdf, tipo)
    minimo_dibujado(pdf, tipo)
    direccion_dibujada(pdf, tipo)
    preguntas_de(pdf, tipo)
  end

  # La escalera va dibujada a mano y no con `tabla`: prawn-table no deja meter
  # una barra adentro de una celda, y la barra es lo que hace que se entienda
  # de un vistazo que el precio baja con el peso.
  def escalera_dibujada(pdf, tipo)
    tramos = escalera(tipo)
    if tramos.empty?
      p_(pdf, "<b>Sin tarifa cargada.</b> Este servicio no tiene precios en el sistema.")
      return
    end

    h2(pdf, tramos.size > 1 ? "Precio por libra, según el peso" : "Precio por libra")

    tope = tramos.map { |t| t[:precio] }.max
    tramos.each do |t|
      pdf.move_down 3
      y = pdf.cursor
      pdf.text_box rango(t), at: [ 0, y ], width: 190, size: 9.5
      pdf.text_box "$#{format('%.2f', t[:precio])}", at: [ 195, y ], width: 55, size: 9.5, style: :bold

# La barra solo aporta cuando hay con qué comparar. Con un tramo único
# ocuparía todo el ancho y no diría nada.
if tramos.size > 1
  pdf.fill_color TEAL
  pdf.fill_rectangle [ 262, y - 2 ], (t[:precio] / tope * 250).round, 8
  pdf.fill_color "000000"
end
      pdf.move_down 14
    end
    pdf.move_down 6
  end

  def minimo_dibujado(pdf, tipo)
    m = minimo(tipo)
    return if m.nil?

    h2(pdf, "Cobro mínimo")
    if m[:moneda] == "LPS"
      p_(pdf, "<b>L.#{format('%.2f', m[:monto])}</b> + ISV = <b>L.#{format('%.2f', m[:con_isv])}</b>. " \
              "Si el flete calculado da menos que eso, se cobra el mínimo.")
    else
      p_(pdf, "<b>$#{format('%.2f', m[:monto])} USD</b> + ISV. " \
              "Es el único servicio con el mínimo en dólares; los otros cuatro lo tienen en lempiras.")
    end
  end

  def direccion_dibujada(pdf, tipo)
    d = direccion(tipo)
    h2(pdf, "Dirección de Miami para este servicio")

    tarjeta(pdf, 62)
    pdf.move_down 10
    pdf.indent(14) do
      pdf.text "NOMBRE:  [CÓDIGO DEL CLIENTE] [NOMBRE COMPLETO]", size: 9
      pdf.text "LÍNEA 1:  #{d[:linea1]}", size: 9
      pdf.fill_color NAVY
      pdf.text "LÍNEA 2:  #{d[:linea2]}", size: 9, style: :bold
      pdf.fill_color "000000"
    end
    pdf.move_down 22
    p_(pdf, "La <b>línea 2</b> cambia según el servicio — es lo que más se escribe mal.", size: 9)
  end

  # Las preguntas de ESTE servicio, acá y no al final: separar la pregunta de
  # su dato invita a respuestas contradictorias, y así fue como Yusef contestó
  # el cuestionario anterior.
  def preguntas_de(pdf, tipo)
    diferencias = DIVERGENCIAS[tipo.codigo]
    return if diferencias.blank?

    diferencias.each do |d|
      pregunta(pdf, d[:numero], d[:titulo])
      p_(pdf, d[:cuerpo])
      d[:opciones].each { |o| opcion(pdf, o) }
      opcion(pdf, "Otro:")
      linea(pdf)
      linea(pdf, "Notas:")
    end
  end

  def cadena_de_cobro(pdf)
    h1(pdf, "Cómo se calcula lo que se cobra")

    p_(pdf, "Un ejemplo real recorriendo todos los pasos: una caja de <b>8 × 9 × 9 pulgadas</b> " \
            "que pesa <b>30 libras</b>, de un cliente con precio de lista en CER.")
    pdf.move_down 4

    tabla(pdf, [ "#", "Paso", "En el ejemplo" ], [
      [ "1", "Volumen de la caja", "8 × 9 × 9 = 648 pulgadas³" ],
      [ "2", "Peso volumétrico: volumen ÷ 166", "648 ÷ 166 = 3.90 lb" ],
      [ "3", "Se redondea a media libra", "3.90 → <b>4.0 lb</b>" ],
      [ "4", "Se cobra el <b>mayor</b> entre el real y el volumétrico", "máx(30.0 , 4.0) = <b>30.0 lb</b>" ],
      [ "5", "¿En qué tramo cae?", "0 – 50.5 lb → $4.50 /lb" ],
      [ "6", "Peso × precio", "30.0 × 4.50 = <b>$135.00</b>" ],
      [ "7", "¿Llega al mínimo?", "sí, lo supera" ],
      [ "8", "Se pasa a lempiras", "$135.00 × 27.10 = L.3,658.50" ],
      [ "9", "ISV, una sola vez, al final", "+ 15% = <b>L.4,207.28</b>" ]
    ], anchos: [ 26, 250, 246 ])

    h2(pdf, "El redondeo a media libra")
    p_(pdf, "Yusef lo explicó así, y es lo que hace el sistema con el <b>peso volumétrico</b>:")
    cita(pdf, "El uno punto cero nueve sigue siendo uno. Uno punto uno ya es uno y medio. " \
              "Uno y medio pues uno y medio. Y de uno punto seis ya sube.")

    h2(pdf, "Un detalle que mueve plata")
    p_(pdf, "Cuando el peso redondeado cambia de tramo, el sistema <b>vuelve a buscar</b> el " \
            "precio con el peso que de verdad se va a cobrar. Sin eso, un CER de 50.2 lb se " \
            "cobraba a $4.50 (el tramo de abajo) en vez de $4.00: <b>$227.25 en vez de $202.00</b>.")

    preguntas_generales(pdf)
  end

  def preguntas_generales(pdf)
    DIVERGENCIAS["general"].each do |d|
      pregunta(pdf, d[:numero], d[:titulo])
      p_(pdf, d[:cuerpo])
      d[:opciones].each { |o| opcion(pdf, o) }
      opcion(pdf, "Otro:")
      linea(pdf)
      linea(pdf, "Notas:")
    end
  end

  def viaje_del_paquete(pdf)
    h1(pdf, "Por dónde pasa un paquete")

    p_(pdf, "Los estados por los que va pasando, en orden. Algunos los mueve una <b>persona</b> " \
            "desde su pantalla; otros los mueve el <b>sistema solo</b> cuando pasa algo.")
    pdf.move_down 4

    tabla(pdf, [ "Estado", "Quién lo mueve", "Qué lo dispara" ], [
      [ "Recibido en Miami", "una persona", "el digitador lo etiqueta al llegar el camión" ],
      [ "Empacado", "una persona", "se guarda en la caja de salida" ],
      [ "Enviado a Honduras", "<b>el sistema</b>", "se envía el manifiesto" ],
      [ "En aduana", "una persona", "lo marca quien lo recibe en Honduras" ],
      [ "Disponible para entrega", "una persona", "salió de aduana y está en bodega" ],
      [ "Pre-facturado", "<b>el sistema</b>", "se confirma la pre-factura" ],
      [ "Facturado", "<b>el sistema</b>", "se factura la pre-factura" ],
      [ "En reparto", "<b>el sistema</b>", "sale la entrega" ],
      [ "Entregado", "<b>el sistema</b>", "se confirma la entrega" ]
    ], anchos: [ 150, 110, 262 ])

    h2(pdf, "Y los que se salen del camino")
    p_(pdf, "<b>Retenido</b>, <b>retornado</b>, <b>desechado</b> y <b>anulado</b> no son pasos: " \
            "son salidas. Un paquete puede caer ahí desde cualquier punto, y el sistema no lo " \
            "cuenta como que retrocedió.")

    h2(pdf, "Una regla que conviene saber")
    p_(pdf, "Un paquete <b>no puede avanzar si tiene tareas pendientes</b>. El sistema lo frena " \
            "y dice cuáles son.")
  end

  # ── Las preguntas ───────────────────────────────────────────────────────
  #
  # Cada una nace de una diferencia entre la documentación de abril y lo que el
  # sistema hace hoy, verificada contra la base. Numeradas desde RP-24 para que
  # las respuestas entren directo en docs/05_requerimientos_conversaciones.md.
  DIVERGENCIAS = {
    "express" => [
      { numero: "RP-24", titulo: "EXPRESS: ¿cuánto vale la libra?",
        cuerpo: "La hoja de abril dice <b>$8.00</b>. El sistema cobra <b>$7.50</b>.",
        opciones: [ "Está bien $7.50 — hay que corregir el documento",
                    "Son $8.00 — hay que corregir el sistema" ] },
      { numero: "RP-25", titulo: "EXPRESS: ¿cuál es el cobro mínimo?",
        cuerpo: "La hoja de abril dice <b>$14.95 con ISV</b>. El sistema cobra <b>$10.00 más ISV</b>. " \
                "Es el único servicio con el mínimo en dólares.",
        opciones: [ "Está bien $10.00 más ISV",
                    "Son $14.95 con ISV incluido" ] }
    ],
    "cem" => [
      { numero: "RP-26", titulo: "CEM: el mínimo de 8 libras no se está aplicando",
        cuerpo: "La documentación dice <b>mínimo 8 libras</b>, pero el sistema cobra el mínimo " \
                "en dinero (L.200.00 con ISV) y no mira las libras. Un paquete de 2 libras paga " \
                "L.200.00, no el precio de 8 libras.",
        opciones: [ "Está bien así: manda el mínimo en dinero",
                    "Tiene que ser por libras: cobrar como si pesara 8" ] }
    ],
    "ckm" => [
      { numero: "RP-27", titulo: "CKM: ¿cuánto vale la libra?",
        cuerpo: "La hoja de abril dice <b>$1.50</b>. El sistema cobra <b>$1.90</b> " \
                "(de 13.5 a 100.5 libras).",
        opciones: [ "Está bien $1.90 — hay que corregir el documento",
                    "Son $1.50 — hay que corregir el sistema" ] },
      { numero: "RP-28", titulo: "CKM: dos reglas que se contradicen",
        cuerpo: "En el mismo audio quedaron dos reglas, y CKM entra en las dos: " \
                "<b>“los servicios serie CK son 200 lempiras ya con ISV”</b> — y CKM es serie CK. " \
                "<b>“el marítimo lo tenemos en cantidad de libras, mínimo 3 o 4”</b> — y CKM es " \
                "marítimo. Hoy el sistema aplica el de dinero.",
        opciones: [ "Manda el de dinero: L.200.00 con ISV",
                    "Manda el de libras: mínimo 3 o 4 libras" ] }
    ],
    "general" => [
      # RP-29 vivia aca y se fue: preguntaba si prender el redondeo escalonado, y
      # Yusef ya lo habia contestado tres dias antes — RP-03 "Prendanlo ya" y RP-04
      # "Todo". El PDF se armo leyendo el estado del codigo ("esta apagado") sin
      # cruzarlo contra las respuestas que ya habian llegado, y termino ofreciendole
      # las dos opciones que el habia descartado.
      #
      # Volver a preguntarle lo que ya cerro le hace perder la confianza en el
      # documento. El redondeo ya esta puesto (`RedondeoMediaLibraSiempre`).
    ]
  }.freeze

  # ── Formato ─────────────────────────────────────────────────────────────

  def sla_bonito(tipo)
    tipo.sla.to_s.sub("dias habiles", "días hábiles")
  end

  def si_no(valor)
    valor ? "Sí" : "no"
  end

  def rango(t)
    return "#{format('%g', t[:desde])} lb en adelante" if t[:hasta].nil?
    "#{format('%g', t[:desde])} – #{format('%g', t[:hasta])} lb"
  end

  # El precio de las PRIMERAS libras, que es el que paga cualquiera.
  #
  # Poner el más bajo sería engañoso: en CKM ese $1.65 solo aplica pasando las
  # 200 libras, y las primeras cuestan $4.00.
  def precio_entrada_texto(tipo)
    primero = escalera(tipo).first
    return "—" if primero.nil?
    "$#{format('%.2f', primero[:precio])}"
  end

  # Lo más barato que llega a costar, y desde cuánto peso.
  def precio_piso_texto(tipo)
    tramos = escalera(tipo)
    return "—" if tramos.empty?
    return "no baja" if tramos.size == 1

    piso = tramos.min_by { |t| t[:precio] }
    "$#{format('%.2f', piso[:precio])}\ndesde #{format('%g', piso[:desde])} lb"
  end

  def tramos_texto(tipo)
    n = escalera(tipo).size
    n <= 1 ? "precio único" : "#{n} tramos"
  end

  def minimo_corto(tipo)
    m = minimo(tipo)
    return "—" if m.nil?
    m[:moneda] == "LPS" ? "L.#{format('%.0f', m[:con_isv])}" : "$#{format('%.0f', m[:monto])}"
  end

  MESES = %w[enero febrero marzo abril mayo junio julio agosto
             septiembre octubre noviembre diciembre].freeze

  def fecha_larga
    hoy = Date.current
    "#{hoy.day} de #{MESES[hoy.month - 1]} de #{hoy.year}"
  end
end
