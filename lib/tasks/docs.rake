# Documentos que se le entregan al cliente para revisión.
#
# Viven versionados en docs/entregables/ para que cualquiera los tenga a mano
# sin regenerarlos, y se regeneran desde acá cuando la documentación cambia —
# así el binario nunca queda huérfano de su fuente.
#
#   bin/rails docs:entregables      # ambos
#   bin/rails docs:resumen_pdf
#   bin/rails docs:preguntas_xlsx
namespace :docs do
  DESTINO = Rails.root.join("docs/entregables")

  desc "Genera el resumen en PDF para que Yusef revise"
  task resumen_pdf: :environment do
    require "prawn"
    require "prawn/table"

    destino = DESTINO.join("resumen_para_yusef.pdf")
    FileUtils.mkdir_p(DESTINO)

      NAVY = "1B2559"
      GOLD = "E69E2E"
      TEAL = "0096C7"
      GRIS = "6B7280"
      ROJO = "B91C1C"

      pdf = Prawn::Document.new(page_size: "LETTER", margin: [ 50, 45, 45, 45 ])
      fonts = Rails.root.join("vendor/fonts")
      if File.exist?(fonts.join("DejaVuSans.ttf"))
        pdf.font_families.update("DejaVu" => {
          normal: fonts.join("DejaVuSans.ttf").to_s,
          bold: fonts.join("DejaVuSans-Bold.ttf").to_s
        })
        pdf.font "DejaVu"
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

      # ── Portada ──
      pdf.fill_color NAVY
      pdf.text "Compras Express Cargo", size: 24, style: :bold
      pdf.fill_color GOLD
      pdf.text "Resumen para revisión", size: 15, style: :bold
      pdf.fill_color GRIS
      MESES = %w[enero febrero marzo abril mayo junio julio agosto
                 septiembre octubre noviembre diciembre].freeze
      hoy = Date.current
      pdf.text "Lo construido y lo que falta confirmar  ·  #{hoy.day} de #{MESES[hoy.month - 1]} de #{hoy.year}", size: 9.5
      pdf.fill_color "000000"
      pdf.move_down 16

      pdf.bounding_box([ 0, pdf.cursor ], width: pdf.bounds.width) do
        pdf.fill_color "F8F9FB"
        pdf.fill_rounded_rectangle([ 0, pdf.cursor ], pdf.bounds.width, 76, 5)
        pdf.fill_color "000000"
        pdf.move_down 12
        pdf.indent(14) do
          pdf.text "Para qué es este documento", size: 10.5, style: :bold
          pdf.move_down 3
          pdf.text "Recoge lo que se habló en las reuniones del 1 y 2 de agosto y lo traduce a " \
                   "lo que ya quedó funcionando en el sistema. Al final hay una lista corta de " \
                   "cosas que solo vos podés decidir — sin esas, no podemos cargar los precios reales.",
                   size: 9.5, leading: 2.5
        end
      end
      pdf.move_down 22

      # ── 1. Tarifas ──
      h1(pdf, "1. Cómo cobra el sistema ahora")

      p_(pdf, "Antes el sistema solo sabía el <b>precio por libra</b> y nada más: no conocía los cobros " \
              "mínimos, ni los precios escalonados, ni las excepciones. Ahora sí.")

      h2(pdf, "Las cuatro reglas que antes manejabas a mano")
      tabla(pdf,
        [ "Regla", "Cómo funciona ahora" ],
        [
          [ "<b>Precio escalonado</b>", "Se carga una fila por tramo de peso: de 1 a 3 libras un precio, de 3 en adelante otro." ],
          [ "<b>Precio especial por cliente</b>", "Un precio puntual para un cliente en <b>un solo servicio</b> — el que “arranca arriba de la tabla”." ],
          [ "<b>Excepciones sin mínimo</b>", "Categorías como Exchange/Shein cobran por libra sin piso, y por <b>media libra</b> si hace falta." ],
          [ "<b>Promociones por proveedor</b>", "Shein, Temu, doTERRA, Farmasi pueden tener su propia tarifa." ]
        ], anchos: [ 150, 337 ])

      h2(pdf, "Qué precio gana cuando hay varios")
      p_(pdf, "El sistema busca de lo más específico a lo más general, y se queda con el primero que encuentre:")
      tabla(pdf,
        [ "#", "Nivel", "Ejemplo" ],
        [
          [ "1", "Precio especial del cliente", "A Jorge le damos el marítimo a $1.50" ],
          [ "2", "Promoción del proveedor", "Todo lo que venga de Shein" ],
          [ "3", "Categoría del cliente", "Mayorista, revendedor, familia…" ],
          [ "4", "Precio de lista", "El público" ]
        ], anchos: [ 22, 175, 290 ])
      p_(pdf, "Y si una <b>sucursal</b> tiene precio distinto por el costo extra de transporte, ese le gana al general.")

      h2(pdf, "Los mínimos, tal como los dictaste")
      tabla(pdf,
        [ "Servicio", "Regla", "Qué hace el sistema" ],
        [
          [ "<b>Serie CK</b>", "L.200 <b>ya con ISV</b>", "Guarda L.173.91 y al facturar vuelve a dar los L.200 que cobrás" ],
          [ "<b>Marítimo</b>", "Mínimo de 3 o 4 libras", "Un paquete de 1.5 lb se cobra como si pesara 4" ],
          [ "<b>Express</b>", "$10 <b>más</b> impuesto", "Cobra $10 y el ISV se suma aparte" ]
        ], anchos: [ 78, 130, 279 ])
      p_(pdf, "Fijate en el contraste: la serie CK son 200 <b>con el impuesto adentro</b>, y Express es $10 " \
              "<b>más</b> impuesto. Los dos casos conviven — por eso, cuando cargues un mínimo, el sistema " \
              "te pregunta el monto tal como lo cobrás y él hace la cuenta.")

      pdf.start_new_page

      # ── 2. Pantallas ──
      h1(pdf, "2. Lo que cambió en las pantallas")

      h2(pdf, "Tabla de Servicios (nueva)")
      p_(pdf, "La pantalla que faltaba. Ahí cargás y cambiás todos los precios vos mismo, sin pedirlo.")
      cita(pdf, "No tenés todavía la tabla de servicio. Creo que las puse a mano.")
      p_(pdf, "Se llega desde el menú principal → <b>Catálogos → Tabla de Servicios</b>.")

      h2(pdf, "Entrega Personal")
      tabla(pdf,
        [ "Cambio", "Detalle" ],
        [
          [ "<b>Valor a pagar</b>", "Ahora muestra cuánto se le cobra al cliente, <b>en dólares y en lempiras</b>, con el ISV, según la tarifa que tenga asignado." ],
          [ "<b>Peso y medidas</b>", "Se copió la calculadora de Etiquetar: peso volumétrico y peso a cobrar en vivo." ],
          [ "<b>Proveedor ≠ Driver</b>", "Eran un solo campo y estaba mal. Ahora <b>Proveedor</b> es la empresa que lo mandó y <b>Driver</b> es la persona que lo trajo, editable, y sale impresa en la etiqueta." ]
        ], anchos: [ 118, 369 ])

      h2(pdf, "Etiquetar")
      tabla(pdf,
        [ "Cambio", "Detalle" ],
        [
          [ "<b>Buscar clientes</b>", "Ya podés escribir “Juan Perez” completo, o “2 María”. Y los ceros no importan: <b>C002 encuentra a C2</b>." ],
          [ "<b>Tecla F4</b>", "Muestra u oculta el campo de tercero, que ahora arranca escondido." ],
          [ "<b>Tracking repetido</b>", "El aviso ahora muestra también el <b>contenido</b> y el <b>tipo de servicio</b>." ],
          [ "<b>Remitente</b>", "Bajó junto a Carrier y Proveedor, que son los tres el “de dónde viene”." ]
        ], anchos: [ 118, 369 ])

      h2(pdf, "La etiqueta")
      p_(pdf, "Antes el sistema imprimía la hoja carta del Warehouse Receipt y se usaba como si fuera la etiqueta.")
      cita(pdf, "Aquí está tirando el warehouse, no la etiqueta.")
      p_(pdf, "Ahora son <b>dos documentos distintos</b>. La etiqueta nueva es <b>Dymo 2.25 × 1.25 pulgadas</b>, " \
              "una por paquete, y lleva por primera vez un <b>código de barras</b> del número de recepción — " \
              "antes el tracking había que teclearlo a mano.")
      p_(pdf, "La sucursal ahora sale bajo el encabezado <b>“RETIRA EN”</b>, en español y sin cortar. Ese era " \
              "el “¿qué es San Pedro Soda?”.")

      h2(pdf, "Menú principal")
      p_(pdf, "Se agregaron los catálogos que solo se alcanzaban desde el menú lateral: Tarifas de Recolecta, " \
              "Servicios Extra, Proveedores, Motivos de Retención y Plantillas de Notas. Y se quitaron los " \
              "cuatro botones que no llevaban a ningún lado.")

      pdf.start_new_page

      # ── 3. Errores encontrados ──
      h1(pdf, "3. Errores que se encontraron y se corrigieron")

      p_(pdf, "Al revisar el cálculo del cobro aparecieron cosas que estaban mal desde antes. Ninguna la " \
              "habían reportado, así que vale la pena que las sepas.")

      tabla(pdf,
        [ "Qué pasaba", "Efecto real" ],
        [
          [ "<b>Los precios en dólares se mostraban como lempiras</b>", "Un CER de 10 libras aparecía como <b>L.45.00</b> cuando en realidad son <b>$45</b> — unas 25 veces menos de lo que corresponde cobrar." ],
          [ "<b>El cobro de prepagado en Miami quedaba en cero</b>", "La línea simbólica de $1 se guardaba en $0 sin avisar." ],
          [ "<b>El peso volumétrico no coincidía</b>", "La pantalla de Etiquetar mostraba un peso y la factura cobraba otro: 3.90 libras en vez de 4." ],
          [ "<b>Doble impuesto en servicios extra</b>", "A un servicio que ya traía el ISV adentro se le volvía a sumar el 15%." ],
          [ "<b>La tasa del dólar se sobrescribía sola</b>", "Un proceso automático la cambiaba todas las mañanas a las 6am. Ya se desactivó: ahora la tasa la fijás vos." ]
        ], anchos: [ 175, 312 ])

      # ── 4. Pendientes ──
      h1(pdf, "4. Lo que falta que decidas vos")

      pdf.fill_color ROJO
      pdf.text "Sin esto no podemos cargar los precios reales al sistema.", size: 10, style: :bold
      pdf.fill_color "000000"
      pdf.move_down 8

      tabla(pdf,
        [ "#", "Qué se necesita", "Estado" ],
        [
          [ "1", "<b>La tabla de precios completa</b> — por cada categoría (revendedores, mayoristas, personal CEC, amigos, familia, Exchange, carga especial) y cada servicio: precio por libra, escalones si los hay, y mínimo.", "Quedaste de enviarla. Va en la hoja 2 del Excel adjunto." ],
          [ "2", "<b>El mínimo por defecto de CEM y CKM.</b> Dijiste que depende del producto o la promoción, pero hace falta uno base para arrancar.", "¿8 y 20 libras como está documentado de abril, u otro?" ],
          [ "3", "<b>El mínimo de EXPRESS.</b> Dijiste que lo cambiaban “para volver más atractivo el servicio”.", "¿A cuánto queda? En abril figuraba $14.95." ],
          [ "4", "<b>Cuáles campos son imprescindibles en la etiqueta.</b> A 2.25 × 1.25 pulgadas no caben los 11 que anotaste.", "Marcalos en la hoja 3 del Excel." ],
          [ "5", "<b>Qué significa “Label en el celular”</b>, de tus notas.", "Es opción múltiple en el Excel para que no quede ambiguo." ]
        ], anchos: [ 22, 300, 165 ])

      h2(pdf, "Una contradicción que hay que resolver")
      p_(pdf, "En el audio de tarifas decís dos cosas que chocan para el mismo servicio:")
      cita(pdf, "Los servicios serie CK son 200 lempiras ya con ISV.")
      cita(pdf, "El marítimo lo tenemos estipulado en cantidad de libras… mínimo 3 o 4 libras.")
      p_(pdf, "<b>CKM es de la serie CK y además es marítimo</b>, así que entra en las dos reglas. " \
              "¿Cuál manda para CKM: el mínimo de L.200, el de libras, o los dos y gana el que resulte mayor? " \
              "El sistema soporta las tres opciones — es decisión tuya.")

      h2(pdf, "Un detalle antes de que pruebes Entrega Personal")
      p_(pdf, "No hay ningún proveedor de tipo “entrega personal” cargado, así que la pantalla te va a decir " \
              "que faltan configurar. Es el proveedor <b>“Entrega local / personal”</b> que dijiste que ibas a crear. " \
              "Se agrega desde <b>Catálogos → Proveedores</b>.")

      pdf.move_down 14
      pdf.stroke_color "D4D4D4"
      pdf.stroke_horizontal_rule
      pdf.stroke_color "000000"
      pdf.move_down 6
      pdf.fill_color GRIS
      pdf.text "Detalle técnico completo en docs/05 (Conversaciones 4 y 5) y docs/06 (Fases 10 y 11) del repositorio.",
               size: 8
      pdf.fill_color "000000"

      pdf.number_pages "<page> / <total>", at: [ pdf.bounds.right - 60, -22 ], size: 8, color: GRIS

      pdf.render_file destino.to_s

    puts "  ✓ #{destino.relative_path_from(Rails.root)}"
  end

  desc "Genera el Excel de preguntas + plantilla de tarifas para Yusef"
  task preguntas_xlsx: :environment do
    require "caxlsx"

    destino = DESTINO.join("preguntas_para_yusef.xlsx")
    FileUtils.mkdir_p(DESTINO)



      pkg = Axlsx::Package.new
      wb  = pkg.workbook

      navy    = wb.styles.add_style(bg_color: "1B2559", fg_color: "FFFFFF", b: true, alignment: { horizontal: :center, vertical: :center, wrap_text: true }, sz: 11)
      gold    = wb.styles.add_style(bg_color: "FFB547", fg_color: "1B2559", b: true, alignment: { horizontal: :center, vertical: :center, wrap_text: true }, sz: 11)
      wrap    = wb.styles.add_style(alignment: { vertical: :top, wrap_text: true }, sz: 10)
      wrapb   = wb.styles.add_style(alignment: { vertical: :top, wrap_text: true }, b: true, sz: 10)
      llenar  = wb.styles.add_style(bg_color: "FFF7E6", border: { style: :thin, color: "E69E2E" }, alignment: { vertical: :top, wrap_text: true }, sz: 10)
      gris    = wb.styles.add_style(bg_color: "F3F4F6", alignment: { vertical: :top, wrap_text: true }, sz: 10)
      titulo  = wb.styles.add_style(sz: 14, b: true, fg_color: "1B2559")
      nota    = wb.styles.add_style(sz: 9, i: true, fg_color: "8A6D3B", alignment: { wrap_text: true, vertical: :top })

      # ─────────────────────────────────────────────────────────────
      # Hoja 1 — Preguntas
      # ─────────────────────────────────────────────────────────────
      wb.add_worksheet(name: "1. Preguntas") do |s|
        s.add_row [ "Preguntas para Yusef — 2026-08-02" ], style: titulo
        s.add_row [ "Llená solo la columna amarilla. Lo demás es contexto para que no tengas que acordarte." ], style: nota
        s.add_row []
        s.add_row [ "#", "Tema", "Pregunta", "Lo que sabemos hoy", "TU RESPUESTA" ],
                  style: [ navy, navy, navy, navy, gold ]

        [
          [ "1", "Tabla de precios",
            "La tabla completa de precios por categoría y servicio. Está en la hoja 2 de este archivo — es lo único que bloquea que podamos sembrar el sistema.",
            "Dijiste: \"esta te la envío mañana\". Enumeraste estas categorías: revendedores (los más bajos), mayoristas (intermedio), personal de CEC (también de los más bajos), clientes amigos, familia, Exchange/Chain, y empresas de carga especial. Hoy el sistema solo tiene Regular, VIP y Mayorista.",
            "→ Ver hoja 2" ],
          [ "2", "Mínimo CEM y CKM",
            "¿Cuál es el mínimo POR DEFECTO de CEM y CKM, para arrancar? Después le agregamos las excepciones por promoción.",
            "Dijiste: \"ni sé cuál es el mínimo exacto, porque depende del tipo de producto o promoción, como Shein, Temu, doTERRA o Farmasi\". Documentado en abril: CEM = 8 libras, CKM = 20 libras. En el audio dijiste 3 o 4 libras.",
            "" ],
          [ "3", "Mínimo EXPRESS",
            "¿A cuánto queda el mínimo de EXPRESS?",
            "Dijiste: \"lo cambiamos para volver más atractivo el servicio\". Documentado en abril: $14.95 con ISV incluido. En el audio mencionaste $10 más ISV.",
            "" ],
          [ "4", "Etiqueta — qué cabe",
            "La etiqueta de ETIQUETAR mide 2.25 x 1.25 pulgadas (Dymo). A ese tamaño NO caben los 11 campos legibles con el código de barras encima. ¿Cuáles son los 4 o 5 imprescindibles, los que el operario tiene que leer de lejos en la estantería?",
            "Nuestra apuesta: (1) código de barras, (2) número de recepción, (3) código + nombre del cliente, (4) sucursal donde retira, (5) n/N de paquetes. Los 11 campos están listados en la hoja 3.",
            "" ],
          [ "5", "\"Label en el celular\"",
            "En tus notas escribiste \"Label en el celular\" pero no aparece en ningún audio. Marcá UNA opción:\n\n(a) imprimir desde el teléfono a una etiquetadora Bluetooth\n(b) que el operario vea la etiqueta en pantalla, sin imprimir\n(c) escanear la etiqueta con el teléfono en vez del pistolete\n(d) que el cliente la vea desde su celular",
            "Apareció justo cuando comentabas que se te dañó la impresora, así que sospechamos que va por ahí. Si es (d), sale de este bloque de trabajo y se cotiza aparte porque es portal del cliente, no operación de Miami.",
            "" ]
        ].each do |row|
          s.add_row row, style: [ wrapb, wrap, wrap, gris, llenar ]
        end

        s.column_widths 4, 18, 52, 58, 34
        s.rows[3..].each { |r| r.height = 90 }
      end

      # ─────────────────────────────────────────────────────────────
      # Hoja 2 — Tarifas (la plantilla que necesitamos llena)
      # ─────────────────────────────────────────────────────────────
      SERVICIOS = TipoEnvio.activos.order(:precio_libra).reverse_order.map { |t|
        { codigo: t.codigo.to_s.upcase, nombre: t.nombre, precio: t.precio_libra, modalidad: t.modalidad }
      }

      EXISTENTES = CategoriaPrecio.order(:id).map { |c|
        { nombre: c.nombre, aereo: c.precio_libra_aereo, maritimo: c.precio_libra_maritimo }
      }

      NUEVAS = [ "Revendedores", "Personal CEC", "Clientes amigos", "Familia", "Exchange / Chain", "Carga especial" ]

      MINIMOS_DOC = {
        "CER"     => { monto: "200.00", moneda: "LPS", isv: "Sí", libras: "" },
        "CKA"     => { monto: "200.00", moneda: "LPS", isv: "Sí", libras: "" },
        "EXPRESS" => { monto: "14.95",  moneda: "USD", isv: "Sí", libras: "" },
        "CEM"     => { monto: "",       moneda: "",    isv: "",   libras: "8" },
        "CKM"     => { monto: "",       moneda: "",    isv: "",   libras: "20" }
      }

      wb.add_worksheet(name: "2. Tarifas") do |s|
        s.add_row [ "Tabla de precios — llenar y devolver" ], style: titulo
        s.add_row [ "Una fila por servicio y categoría. Si un servicio tiene precio ESCALONADO por peso (\"de 1 a 3 libras vale tanto, de 3 en adelante vale tanto\"), agregá una fila más por cada escalón usando las columnas Desde/Hasta." ], style: nota
        s.add_row [ "Las celdas amarillas son las que necesitamos. Las grises son lo que el sistema tiene hoy, para referencia." ], style: nota
        s.add_row []
        s.add_row [
          "Servicio", "Categoría de cliente", "Desde (lb)", "Hasta (lb)",
          "Precio x libra", "Moneda", "Mínimo (monto)", "Moneda del mínimo",
          "¿El mínimo ya trae ISV?", "Mínimo (libras)", "¿Aplica mínimo?",
          "Incremento (lb)", "Notas"
        ], style: navy

        SERVICIOS.each do |srv|
          m = MINIMOS_DOC.fetch(srv[:codigo], { monto: "", moneda: "", isv: "", libras: "" })

          # Fila de lista (precio público) — pre-llenada con lo que hay hoy
          s.add_row [
            "#{srv[:codigo]} — #{srv[:nombre]}", "(precio de lista / público)", 0, "",
            srv[:precio], "USD", m[:monto], m[:moneda], m[:isv], m[:libras], "Sí", 1,
            "Precio actual del sistema. Mínimos según lo documentado en abril — confirmar."
          ], style: [ wrapb, gris, llenar, llenar, llenar, llenar, llenar, llenar, llenar, llenar, llenar, llenar, wrap ]

          # Categorías que ya existen
          EXISTENTES.each do |cat|
            actual = srv[:modalidad] == "maritimo" ? cat[:maritimo] : cat[:aereo]
            alerta = if actual && srv[:precio] && actual < srv[:precio]
              "⚠ Hoy paga #{actual} cuando la lista es #{srv[:precio]} — el sistema no distingue entre servicios de la misma modalidad."
            end
            s.add_row [
              "#{srv[:codigo]} — #{srv[:nombre]}", cat[:nombre], 0, "",
              actual, "USD", "", "", "", "", "Sí", 1, alerta
            ], style: [ wrapb, gris, llenar, llenar, llenar, llenar, llenar, llenar, llenar, llenar, llenar, llenar, nota ]
          end

          # Categorías nuevas que mencionaste en el audio
          NUEVAS.each do |nom|
            nota_cat = if nom.start_with?("Exchange")
              "Dijiste que acá NO aplica el mínimo y que se cobra por libra o MEDIA libra → poné \"No\" en aplica mínimo e \"0.5\" en incremento."
            end
            s.add_row [
              "#{srv[:codigo]} — #{srv[:nombre]}", nom, 0, "",
              "", "USD", "", "", "", "", "", 1, nota_cat
            ], style: [ wrapb, gris, llenar, llenar, llenar, llenar, llenar, llenar, llenar, llenar, llenar, llenar, nota ]
          end

          s.add_row []
        end

        s.column_widths 26, 22, 11, 11, 14, 9, 14, 15, 16, 14, 13, 13, 52
      end

      # ─────────────────────────────────────────────────────────────
      # Hoja 3 — Etiqueta
      # ─────────────────────────────────────────────────────────────
      wb.add_worksheet(name: "3. Etiqueta") do |s|
        s.add_row [ "Etiqueta de ETIQUETAR — 2.25 x 1.25 pulgadas (Dymo)" ], style: titulo
        s.add_row [ "Estos son los 11 campos que anotaste en la etiqueta que mandaste. Marcá con una X los que SÍ o SÍ tienen que ir, sabiendo que a ese tamaño no caben todos." ], style: nota
        s.add_row []
        s.add_row [ "#", "Campo", "Ejemplo", "Tu nota", "¿Imprescindible? (X)" ], style: [ navy, navy, navy, navy, gold ]

        [
          [ 1,  "Código de barras del número de recepción", "(barras)", "No existe hoy en el sistema — hay que agregarlo" ],
          [ 2,  "Número de recepción", "RE0000577711-2-1/2", "" ],
          [ 3,  "Tracking original", "TBA333187639911-2-1", "\"hay que agregar secundario\"" ],
          [ 4,  "Nombre del cliente", "YUSEF SAMARA", "\"agregar nombre de cliente tercero\"" ],
          [ 5,  "Fecha y hora de recepción", "30-jul.-2026 08:50 a.m.", "" ],
          [ 6,  "Iniciales del usuario que registró", "Y.G.", "Ya existe en el sistema" ],
          [ 7,  "Código del cliente", "C6", "Confirmaste: va el código completo" ],
          [ 8,  "Sucursal donde retira el cliente", "SAN PEDRO SULA", "Hoy sale truncado (\"SAN PEDRO SU\") y sin encabezado que lo explique" ],
          [ 9,  "Número y cantidad de paquetes", "1/2", "Una etiqueta por paquete" ],
          [ 10, "Tipo de envío", "EXP", "" ],
          [ 11, "Departamento y ciudad del cliente", "Cortés · San Pedro Sula", "Confirmaste: departamento abreviado + ciudad o pueblo" ]
        ].each { |r| s.add_row r, style: [ wrapb, wrap, wrap, gris, llenar ] }

        s.add_row []
        s.add_row [ "Los otros formatos que nos comentaste (fuera de este trabajo, para dejar constancia)" ], style: wrapb
        s.add_row [ "Operación", "Tamaño", "Marca", "Dónde se pega", "" ], style: navy
        [
          [ "ETIQUETAR", "2.25 x 1.25 in", "Dymo", "Una por paquete (si el tracking se divide en 5, van 5)", "← este es el que vamos a hacer" ],
          [ "MANIFIESTO", "4 x 6 in", "FreeX", "Una por caja o paquete, pegada", "" ],
          [ "PRE-FACTURA (SPS)", "4 x 6 in", "FreeX", "Pegada por paquete; un paquete puede llevar varios tracking", "" ],
          [ "MANIFIESTO NACIONAL", "4 x 6 in", "FreeX", "Por fuera; lleva varias pre-facturas, que llevan varios tracking", "" ]
        ].each { |r| s.add_row r, style: [ wrapb, wrap, wrap, wrap, nota ] }

        s.column_widths 5, 34, 26, 46, 26
      end

      pkg.serialize(destino.to_s)

    puts "  ✓ #{destino.relative_path_from(Rails.root)}"
  end

  desc "Regenera todos los entregables"
  task entregables: %i[resumen_pdf preguntas_xlsx]
end
