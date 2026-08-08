# Documentos que se le entregan al cliente para revisión.
#
# Viven versionados en docs/entregables/ para que cualquiera los tenga a mano
# sin regenerarlos, y se regeneran desde acá cuando la documentación cambia —
# así el binario nunca queda huérfano de su fuente.
#
#   bin/rails docs:entregables      # ambos
#   bin/rails docs:resumen_pdf
#   bin/rails docs:preguntas_xlsx
# ── Estilo compartido por los documentos ───────────────────────────────
# Constantes y helpers a nivel de archivo: si viven dentro de un task, solo
# existen cuando ESE task corre, y el resto revienta con NameError.

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


namespace :docs do
  DESTINO = Rails.root.join("docs/entregables")

  desc "Genera el resumen en PDF para que Yusef revise"
  task resumen_pdf: :environment do
    require "prawn"
    require "prawn/table"

    destino = DESTINO.join("resumen_para_yusef.pdf")
    FileUtils.mkdir_p(DESTINO)

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

      # ── 4. Precios cargados ──
      h1(pdf, "4. Tus precios ya están cargados")

      p_(pdf, "La tabla que mandaste (<b>precios por categoria 2026.xlsx</b>, hoja PROPUESTA) ya está en el " \
              "sistema. Era lo único que faltaba para que cobrara de verdad: hasta ahora corría con un precio " \
              "plano por servicio, sin mínimos ni escalones.")

      p_(pdf, "Tu archivo confirmó el diseño punto por punto — llegaste por tu cuenta a la misma estructura " \
              "que ya tenía el sistema: precio y mínimo por categoría, tarifario escalonado por rangos de " \
              "libras, una fila aparte para Tegucigalpa, y una categoría sin cobro mínimo. Hasta el " \
              "<b>L.173.91</b>: en la hoja ACTUAL figuraba como $6.45 y en la PROPUESTA lo pasaste al neto " \
              "sin ISV, que es exactamente como lo guarda el sistema.")

      tabla(pdf,
        [ "Qué se cargó", "Detalle" ],
        [
          [ "<b>7 categorías nuevas</b>", "Clientes Amigos, doTERRA / Farmasi, Personal CEC, Shein, Sin Cobro Mínimo, Familia y Revendedores." ],
          [ "<b>Los escalonados</b>", "CER, CEM y CKM cobran distinto según el peso, tal como los definiste." ],
          [ "<b>Tegucigalpa</b>", "El sobrecosto de transporte se aplica <b>solo</b> cuando el paquete va para allá. No es una categoría de cliente y el cajero no elige nada." ],
          [ "<b>Mínimo de EXPRESS</b>", "Queda en <b>$10 sin ISV</b>, como lo pusiste. Con eso se cierra la pregunta que teníamos de abril." ]
        ], anchos: [ 118, 369 ])

      p_(pdf, "<b>Familia</b> y <b>Revendedores</b> venían todos en cero, así que sus clientes pagan precio de " \
              "lista por ahora. De <b>Mayoristas</b> solo vino el precio de CKM.")

      h2(pdf, "Los cargos que no son flete")
      p_(pdf, "De las 16 filas que no son tipos de envío, <b>cargamos cinco</b> — los que tu propia hoja deja " \
              "claros sin que tengamos que interpretar nada:")
      tabla(pdf,
        [ "Cargo", "Precio", "Cómo lo supimos" ],
        [
          [ "<b>Entrega nacional</b>", "L.86.96", "El título dice L100, y 86.96 más ISV da L.100.00 exactos." ],
          [ "<b>Compra online</b>", "$1.00", "Tu nota: “ponerlo $1 más ISV”." ],
          [ "<b>Manejo y gastos de destino</b>", "L.1.00", "Tu nota: “ponerlo lps1 más ISV”." ],
          [ "<b>Flete internacional UPS</b>", "$1.00", "El título de la fila dice “$1”." ],
          [ "<b>Retornado en Miami</b>", "$5.00", "Tu nota: “todo en $”." ]
        ], anchos: [ 150, 60, 277 ])

      p_(pdf, "<b>Los otros diez no los cargamos, y te pedimos que nos digas la moneda.</b> En tu hoja pusiste " \
              "una leyenda de colores —“precios en $” y “precios en lempiras”— pero <b>las celdas de precio " \
              "quedaron sin colorear</b>, así que viendo solo el número no hay cómo saber si un 5 son cinco " \
              "dólares o cinco lempiras. Preferimos preguntarte antes que adivinar: son montos que se le cobran " \
              "al cliente.")

      p_(pdf, "Hay uno que conviene mirar primero: el <b>cambio de servicio</b>. En tu hoja el título dice L100, " \
              "el valor dice 5 y anotaste “pasarlo a dólares” — y en el sistema está cargado hoy en <b>$15</b>. " \
              "Ese cargo se genera <b>solo</b>, en una nota de débito, cada vez que se factura un paquete al que " \
              "le cambiaron el servicio. Así que mientras no lo confirmemos, sigue cobrando los $15.")

      p_(pdf, "<b>En la hoja 2 del Excel está todo lo que quedó cargado</b>, leído directo de la base — es " \
              "literalmente lo que va a cobrar el sistema. Vale la pena que le des una pasada.")

      h2(pdf, "Lo del código del supervisor: entendido")
      p_(pdf, "En casi todas las filas de tus tarifarios escribiste “tarifa editable con autorización de " \
              "supervisor o jefe”. Al principio lo leímos como algo de tu proceso interno. Ya quedó claro " \
              "que <b>es una función del sistema</b>, y así lo dejamos anotado:")
      cita(pdf, "Por eso queremos que el área de los precios estén establecidos, listo. No hay nada más, no se puede hacer más si está todo preestablecido. Ahora, si lo quieren modificar, ellos tienen que pedir autorización — ahí es donde entra un jefe, un supervisor, y ahí es donde llega y pone un código especial de él.")
      p_(pdf, "<b>Ya está construido, con el detalle que nos pasaste:</b>")
      tabla(pdf,
        [ "Paso", "Quién", "Estado" ],
        [
          [ "Los precios se cargan una sola vez en la tabla de servicios", "Solo admin", "Listo" ],
          [ "En la pre-factura el precio sale <b>bloqueado</b>", "Nadie lo edita suelto", "Listo" ],
          [ "Si hay que cambiarlo, el cajero pide autorización", "Cajero", "Listo" ],
          [ "El supervisor teclea <b>su PIN de 4 dígitos</b> y se aplica el cambio", "Supervisor o jefe", "Listo" ],
          [ "Queda registrado quién autorizó qué, contra qué monto y por qué", "El sistema", "Listo" ]
        ], anchos: [ 250, 130, 107 ])

      p_(pdf, "El PIN destraba las cuatro cosas que pediste — <b>precio, descuento, quitar líneas y el peso a " \
              "cobrar</b> — y es <b>por línea</b>, no por pre-factura completa. Autorizan Administrador, " \
              "Supervisor Caja, Supervisor Pre-Factura y el rol nuevo de <b>Supervisor de Servicio al " \
              "Cliente</b>.")

      p_(pdf, "El supervisor <b>no tiene que iniciar sesión</b>: el cajero se queda en su pantalla y el " \
              "supervisor solo teclea sus cuatro dígitos parado ahí. El PIN se guarda cifrado y con límite de " \
              "intentos — son 10.000 combinaciones y es el único lugar del sistema donde cuatro números " \
              "mueven plata.")

      h2(pdf, "El descuento ahora se ve en la factura")
      p_(pdf, "Antes, cuando alguien hacía un descuento le bajaba el precio a la línea: la factura salía más " \
              "barata y <b>nada decía que hubo descuento</b>, ni de cuánto, ni quién lo dio. Ahora es un campo " \
              "propio y sale impreso, en monto o en porcentaje según como lo capturen. El ISV se calcula sobre " \
              "el neto, después del descuento, que es como corresponde.")

      h2(pdf, "Las notas de débito y crédito")
      p_(pdf, "Acá el control quedó en otro lado, y a propósito: la nota <b>no saca su monto de la tabla de " \
              "tarifas</b> — ajustar a mano es justamente para lo que sirve. Trabar cada línea sería trabar lo " \
              "que el documento viene a hacer.")
      p_(pdf, "Entonces el PIN se pide <b>al emitir</b>, que es el momento en que el saldo del cliente cambia. " \
              "Y con una regla más: <b>quien arma la nota no puede emitirla él mismo</b>, la tiene que " \
              "autorizar otra persona. Una nota de crédito es plata que se le devuelve al cliente, así que " \
              "vale que pasen dos por ahí.")

      h2(pdf, "Dónde ver lo autorizado")
      p_(pdf, "Hay una pantalla nueva, <b>Autorizaciones</b>, donde se ve todo junto: qué se cambió, contra " \
              "qué monto estaba antes, quién lo autorizó y por qué. Arriba sale el <b>total descontado</b> y " \
              "el <b>total devuelto en notas de crédito</b> del período que estés viendo. La ven los mismos " \
              "que pueden autorizar.")

      # ── 5. Pendientes ──
      h1(pdf, "5. Lo que falta que decidas vos")

      tabla(pdf,
        [ "#", "Qué se necesita", "Por qué" ],
        [
          [ "1", "<b>¿Hace falta todavía un mínimo en LIBRAS para CEM y CKM?</b>", "Tu tabla trae el mínimo en dinero pero no el de libras. En la práctica el escalonado ya cubre el paquete chico: un CEM de 2 libras paga $4.50 la libra." ],
          [ "2", "<b>Para CKM, ¿cuál mínimo manda</b> — los L.200, el de libras, o el mayor de los dos?", "CKM es de la serie CK <b>y</b> es marítimo, así que entra en las dos reglas que diste. En tu tabla le pusiste L.173.91, así que cargamos ese." ],
          [ "3", "<b>Regular y VIP no aparecen en tu tabla</b> y tienen 8 clientes asignados. ¿A cuál de las nuevas los pasamos?", "Por ahora se quedaron con los precios viejos, que son más bajos que los de lista." ],
          [ "4", "<b>Las categorías no bajan de escalón.</b> Un Clientes Amigos con 200 lb de CER paga $4.20/lb ($840) y el público paga $3.50 ($700).", "Tu tabla da un solo precio por categoría y el escalonado está declarado solo para el precio de lista. Lo cargamos literal — decinos si es lo que querés." ],
          [ "5", "<b>A quiénes les asignamos PIN de autorización.</b>", "Pueden tenerlo Administrador, Supervisor Caja, Supervisor Pre-Factura y Supervisor de Servicio al Cliente." ]
        ], anchos: [ 22, 250, 215 ])

      h2(pdf, "La etiqueta ya quedó")
      p_(pdf, "Nos dijiste que <b>no cambia de tamaño</b> y que “allí es letra pequeña unas y otras grandes”. " \
              "Con eso quedó claro que no había que recortar campos sino graduar el tamaño de letra, así que " \
              "<b>van los 11</b>:")
      tabla(pdf,
        [ "Tamaño", "Qué lleva" ],
        [
          [ "<b>Grande</b> — se lee de lejos en la estantería", "Número de recepción, tipo de envío, código y nombre del cliente, sucursal donde retira, y el n/N de paquetes." ],
          [ "<b>Chico</b> — solo hace falta tenerlo a mano", "Tracking principal y el secundario, tercero, driver, ciudad del cliente, fecha y hora, e iniciales de quien la registró." ]
        ], anchos: [ 175, 312 ])
      p_(pdf, "A ese tamaño va justo, así que cuando la impriman <b>revisá que no se corte la última línea</b> " \
              "(la del n/N, la fecha y las iniciales) en un paquete que traiga tercero y driver a la vez, que " \
              "es el que más campos lleva. Si algo se corta, avisanos y ajustamos.")

      h2(pdf, "De dónde sale la pregunta 2")
      p_(pdf, "En el audio de tarifas decís dos cosas que chocan para el mismo servicio:")
      cita(pdf, "Los servicios serie CK son 200 lempiras ya con ISV.")
      cita(pdf, "El marítimo lo tenemos estipulado en cantidad de libras… mínimo 3 o 4 libras.")
      p_(pdf, "<b>CKM es de la serie CK y además es marítimo</b>, así que entra en las dos. El sistema " \
              "soporta las tres opciones — que mande el monto, que mande las libras, o que gane el mayor.")

      h2(pdf, "Una nota de tus apuntes que ya quedó resuelta")
      p_(pdf, "En la página 2 escribiste “Label en el celular”. Era sobre la <b>etiqueta rota</b>: " \
              "cuando llega dañada y solo se alcanzan a leer pedazos, hay que buscar al cliente con " \
              "lo poco que se ve.")
      cita(pdf, "A veces llegan las etiquetas rotas, solo dicen 234 y después dice Pérez Hernández, entonces uno tiene que andar ahí unificando.")
      p_(pdf, "Ya está: la búsqueda aguanta los pedazos sueltos. Si escribís “234 Pérez Hernández” y solo " \
              "uno de los fragmentos es correcto, igual aparece el cliente — y los que coinciden en más " \
              "pedazos salen primero. Los acentos tampoco importan.")

      h2(pdf, "Propuesta: dejar los proveedores de Entrega Personal precargados")
      p_(pdf, "Hoy no hay ninguno cargado, así que la pantalla de Entrega Personal avisa que faltan " \
              "configurar. Dijiste que ibas a crear el de “Entrega local / personal”, pero en vez de que " \
              "los cargues uno por uno te proponemos <b>dejarlos ya sembrados</b> y que vos ajustes desde ahí.")
      p_(pdf, "Esta sería la lista de arranque. <b>Confirmala, corregila o agregale los que falten</b> — " \
              "no hace falta que esté completa, solo que arranque con lo que más se repite:")
      tabla(pdf,
        [ "Proveedor propuesto", "Cuándo se usa" ],
        [
          [ "<b>Entrega local / personal</b>", "El cliente o alguien de su parte trae el paquete al mostrador." ],
          [ "<b>Uber / delivery</b>", "Llega por una app de mensajería." ],
          [ "<b>Driver particular</b>", "Un conductor suelto, sin empresa detrás. El nombre de la persona va en el campo Driver." ],
          [ "<b>Courier local</b>", "Mensajería local contratada." ]
        ], anchos: [ 140, 347 ])
      p_(pdf, "En cualquier caso, <b>estos valores siempre los podés crear, editar o desactivar vos mismo</b> " \
              "desde <b>Catálogos → Proveedores</b>, sin pedírnoslo. Lo mismo aplica a todos los catálogos " \
              "del sistema: servicios, tarifas de recolecta, servicios extra, motivos de retención y " \
              "plantillas de notas. Precargarlos es solo para que no arranques con la pantalla vacía.")

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
        s.add_row [ "Preguntas para Yusef — #{I18n.l(Date.current, format: '%d de %B de %Y')}" ], style: titulo
        s.add_row [ "Llená solo la columna amarilla. Lo demás es contexto para que no tengas que acordarte de nada." ], style: nota
        s.add_row [ "Están en orden de urgencia: las primeras son las que hoy hacen que el sistema cobre distinto de lo que vos querés." ], style: nota
        s.add_row [ "En la reunión del 8 de agosto ya contestaste tres: el cambio de servicio (L.100), la moneda de los cargos y el redondeo de libras. Esas ya no están acá." ], style: nota
        s.add_row []
        s.add_row [ "#", "Urgencia", "Tema", "Pregunta", "Lo que sabemos hoy", "TU RESPUESTA" ],
                  style: [ navy, navy, navy, navy, navy, gold ]

        [
          # ── Lo que hoy cobra distinto, o bloquea trabajo ──
          [ "1", "ALTA", "Formato del N° de recepcion",
            "Dijiste que al numero de recepcion le falta el MES, y que ya nos lo habias mandado. ¿Nos pasas el formato exacto? Ejemplo de como quedaria un paquete recibido en Miami en agosto 2026.",
            "Hoy el numero es RM + anio + correlativo de 6 digitos: RM0002026000010. El correlativo reinicia cada enero. Cambiar el formato toca todos los numeros ya generados, por eso no lo inventamos nosotros.",
            "" ],
          [ "2", "ALTA", "Redondeo de libras",
            "La regla que diste (1.09 se cobra 1.0, 1.10 se cobra 1.5, 1.60 se cobra 2.0) es para escalones de MEDIA libra. Si armas una tarifa con escalon de 1 libra entera, ¿la tolerancia sigue siendo 0.09?",
            "Hoy el sistema no redondea: cobra el peso exacto. Cuando actives el escalonado va a redondear, y necesitamos la regla completa para no cobrarte de mas a vos ni de menos al cliente.",
            "" ],
          [ "3", "ALTA", "Recolecta: ¿zona o plano?",
            "Vos pediste que la recolecta se cobrara POR ZONA en vez de $35 fijos, y asi esta hecho. En el audio dijiste \"$35 normal, pero hay clientes con descuento\". ¿La recolecta de MIAMI y la de HONDURAS son dos cosas distintas?",
            "Hoy el sistema tiene una tabla de tarifas de recolecta por zona/distancia, que es lo que pediste en su momento. Si el $35 de Miami es otro cargo aparte, conviven los dos sin problema.",
            "" ],
          [ "4", "ALTA", "Manejo y gastos de destino",
            "Tu hoja dice textual \"ponerlo lps1 mas isv\", pero en el audio dijiste que es \"parecido al de ajuste\", y ajuste es en dolares. ¿Lempiras o dolares?",
            "Lo dejamos en Lempiras, que es lo que dice la nota escrita de tu hoja. Es el unico cargo donde el audio y la hoja no coinciden.",
            "" ],

          # ── Los cargos que faltan definir ──
          [ "5", "MEDIA", "Retornado de Miami",
            "Dijiste \"$5 es como un precio minimo\" y que si va por USPS sube a $15 porque hay que pagar motorista. ¿Son dos cargos distintos, o uno con minimo de $5?",
            "Cargado a $5. Si son dos, los damos de alta por separado y en Miami eligen cual aplica.",
            "" ],
          [ "6", "MEDIA", "Entrada y salida (IN & OUT)",
            "Dijiste que es \"de 10 a 5 depende\". ¿De que depende — del tamano del paquete, del cliente, de la cantidad?",
            "Es cuando el cliente recibe en Miami y lo recoge el mismo. Nos diste el ejemplo de 3 paquetes a $5 cada uno.",
            "" ],
          [ "7", "MEDIA", "Flete Mexico y etiqueta internacional",
            "Dos cosas: (a) el flete de Mexico a Honduras, ¿en que moneda? (b) la creacion de etiqueta internacional que mencionaste, ¿que precio y en que moneda?",
            "El flete Mexico esta en tu hoja con precio pero sin moneda. La etiqueta internacional no esta ni en la hoja ni en el sistema — la mencionaste como parte de los retornados de Miami.",
            "" ],

          # ── Operación de etiquetar ──
          [ "8", "MEDIA", "Buscar cliente por los ultimos digitos",
            "Pediste que se pueda escribir solo el final del codigo (2867, o hasta un solo 6) y que caiga. Con codigos de 5 digitos, escribir un 6 va a traer cientos. ¿Mostramos todos los que terminan en 6, o priorizamos el que coincide exacto?",
            "Asi trabajan hoy en el sistema viejo, y los codigos viejos de 4 digitos no se van a migrar.",
            "" ],
          [ "9", "MEDIA", "Guardar: ¿F8 o F10?",
            "En etiquetar guardar es F8, pero en pre-facturas, ventas, caja y financiamientos es F10 — y vos apretaste F10 sin pensarlo. ¿Lo pasamos todo a F10?",
            "F8 en el resto del sistema es \"exportar a Excel\". Si cambiamos, hay que avisarle a Miami que ya tiene el F8 en el dedo.",
            "" ],
          [ "10", "MEDIA", "Peso por caja",
            "Si son 2 cajas, ¿preferis que salgan las 2 lineas de peso y medidas de una vez, o un boton \"agregar\" que las va sumando de a una?",
            "Hoy pide una sola linea aunque sean varias cajas. Vos mencionaste las dos formas y dejaste elegir.",
            "" ],
          [ "11", "MEDIA", "Bajar la cantidad de cajas",
            "Si un paquete tiene 5 cajas y alguien lo baja a 2, las otras 3 se borran. ¿Que hacemos si alguna de esas ya esta facturada o entregada?",
            "Hoy no se borra ninguna y quedan registros de mas, que es el error que viste. Lo mas seguro es no dejar borrar una caja ya facturada y avisar por que.",
            "" ],
          [ "12", "MEDIA", "Origen del paquete",
            "El campo de origen (Estados Unidos / China) esta en pantalla sin definir. ¿Que origenes van, y cambia algo del cobro segun el origen?",
            "Dijiste \"como ahorita estamos en Estados Unidos, pero ya va a abrir China\".",
            "" ],

          # ── Lo que quedaste de mandarnos ──
          [ "13", "MEDIA", "Listas que quedaste de mandar",
            "Nos faltan tres listas tuyas: (a) motivos de retencion completos — sabemos que falta \"solicitado por el cliente para retorno\"; (b) las notas predeterminadas de pre-factura, caja y servicio al cliente; (c) las grabaciones de voz para la alerta de pre-alerta.",
            "Los motivos y las notas van a quedar editables por vos, asi que podes agregarlos vos mismo despues. Las grabaciones son las que hizo tu senora en 2022 — dijiste que las volvias a grabar.",
            "" ],
          [ "14", "MEDIA", "Sonidos de etiquetar",
            "Te vamos a pasar una lista de sonidos para que elijas el de ERROR (el \"feo\", para cuando el paquete no es del tipo de envio de la sesion). ¿Preferis elegir vos o te proponemos uno?",
            "El pin agradable que ya suena lo aprobaste. Faltan: el pito de \"este tracking ya existia\", el de error, y el pin antes de que salga cada modal.",
            "" ],

          # ── Revisar lo que ya quedó cargado ──
          [ "15", "MEDIA", "Revisar los precios cargados",
            "En la HOJA 2 esta TODO lo que quedo cargado de tu tabla, leido directo del sistema. Es literalmente lo que va a cobrar. ¿Esta bien?",
            "Tomamos la hoja PROPUESTA de \"precios por categoria 2026.xlsx\". Si algo esta mal, escribilo en la ultima columna de esa hoja.",
            "" ],
          [ "16", "MEDIA", "Las categorías no bajan de escalón",
            "Un cliente \"Clientes Amigos\" con 200 libras de CER paga $4.20 la libra ($840) mientras el publico paga $3.50 ($700). ¿Es asi, o las categorias tambien deberian bajar de escalon?",
            "Tu tabla da un solo precio por categoria (columna NORMAL) y los tarifarios escalonados los declaraste solo para el Precio Normal. Lo cargamos literal a como lo mandaste, pero el resultado es que un amigo paga mas que un cliente de mostrador en paquetes grandes.",
            "" ],
          [ "17", "MEDIA", "CKM cae en dos reglas",
            "Para CKM, ¿cual minimo manda: los L.200, el de libras, o el que resulte MAYOR de los dos?",
            "En el audio dijiste \"los servicios serie CK son 200 lempiras ya con ISV\" (aplica a CKA y CKM) y tambien \"el maritimo lo tenemos estipulado en cantidad de libras\" (aplica a CEM y CKM). CKM es las dos cosas. En tu tabla le pusiste L.173.91, asi que cargamos ese.",
            "" ],
          [ "18", "MEDIA", "Mínimo en libras de CEM y CKM",
            "¿Hace falta todavia un minimo en LIBRAS para CEM y CKM, o con el minimo en dinero de tu tabla ya esta?",
            "Tu tabla trae el minimo en dinero (L.200 con ISV) pero no el de libras. En la practica el escalonado ya cubre el paquete chico: un CEM de 2 libras paga $4.50 la libra. Documentado en abril: CEM = 8 libras, CKM = 20 libras. En el audio dijiste 3 o 4 libras.",
            "" ],
          [ "19", "MEDIA", "Regular y VIP",
            "Hay 8 clientes en las categorias \"Regular\" y \"VIP\", que no aparecen en tu tabla. ¿A cual de las nuevas los pasamos, o los dejamos como estan?",
            "Por ahora se quedaron con los precios viejos, que son mas bajos que los de lista. Las categorias de tu tabla son: Clientes Amigos, doTERRA/Farmasi, Familia, Mayoristas, Personal de CEC, Shein, Revendedores y Sin Cobro Minimo.",
            "" ],
          [ "20", "MEDIA", "Mayoristas incompleto",
            "De MAYORISTAS solo vino el precio de CKM ($1.50). Los otros cuatro servicios vinieron en cero. ¿Que cobran los mayoristas en CER, CKA, EXPRESS y CEM?",
            "Mientras tanto esos cuatro siguen con los valores viejos del sistema, que no salieron de tu tabla. FAMILIA y REVENDEDORES vinieron todos en cero, asi que sus clientes pagan precio de lista.",
            "" ],

          # ── Operación ──
          [ "21", "MEDIA", "PINs de los supervisores",
            "El codigo del supervisor ya esta funcionando. ¿A quienes les asignamos PIN? Pueden tenerlo: Administrador, Supervisor Caja, Supervisor Pre-Factura y Supervisor de Servicio al Cliente.",
            "Un administrador se los asigna desde la pantalla de usuarios y despues cada supervisor lo cambia por uno que solo el sepa. Mientras no lo cambie, el administrador conoce el PIN con el que ese supervisor autoriza — la pantalla de usuarios marca a quienes les falta cambiarlo.",
            "" ],
          [ "22", "MEDIA", "Probar la etiqueta impresa",
            "Imprimi una etiqueta y decinos dos cosas: (1) si no se corta nada, sobre todo en un paquete que traiga tercero Y driver, que es el que mas campos lleva; (2) si el lector escanea bien el codigo de barras.",
            "Los 11 campos van con la jerarquia de tamanos que marcaste. El codigo de barras quedo en 0.20 pulgadas de alto, que es el minimo practico para lectores de mano — es lo unico que no podemos probar nosotros. Los campos estan en la hoja 3.",
            "" ],
          [ "23", "BAJA", "Proveedores de entrega personal",
            "¿Confirmas esta lista para dejarla precargada? Entrega local / personal, Uber o delivery, Driver particular, Courier local.",
            "Hoy no hay ninguno cargado, asi que la pantalla de Entrega Personal avisa que faltan configurar. En cualquier caso los podes crear, editar o desactivar vos mismo desde Catalogos → Proveedores.",
            "" ]
        ].each do |row|
          s.add_row row, style: [ wrapb, wrapb, wrap, wrap, gris, llenar ]
        end

        s.column_widths 4, 10, 20, 50, 56, 32
        s.rows[4..].each { |r| r.height = 78 }
      end

      # ─────────────────────────────────────────────────────────────
      # Hoja 2 — Tarifas cargadas
      #
      # Dejó de ser una plantilla que Yusef llena: él ya mandó su tabla y está
      # sembrada (PR-10.g). Ahora la hoja LEE lo que quedó en la base, para que
      # confirme que el sistema va a cobrar lo que él quiso decir.
      # ─────────────────────────────────────────────────────────────
      wb.add_worksheet(name: "2. Tarifas cargadas") do |s|
        s.add_row [ "Precios cargados en el sistema — revisar y confirmar" ], style: titulo
        s.add_row [ "Esto es lo que hay HOY en el sistema, leído directo de la base. Es exactamente lo que va a cobrar." ], style: nota
        s.add_row [ "Gana la regla más específica: precio del cliente → promoción del proveedor → categoría → precio de lista. Dentro de la que gane, se usa el escalón de peso que corresponda, y si hay una fila para la sucursal esa manda." ], style: nota
        s.add_row [ "El mínimo se muestra en los dos valores: lo que le cobrás al cliente (con ISV) y el neto que guarda el sistema. Si algo está mal, escribilo en la última columna." ], style: nota
        s.add_row []
        s.add_row [
          "Servicio", "Aplica a", "Sucursal", "Desde (lb)", "Hasta (lb)",
          "Precio x libra", "Mínimo (le cobrás)", "Mínimo (neto)",
          "¿Aplica mínimo?", "Cobro", "¿ESTÁ BIEN? / corrección"
        ], style: [ navy, navy, navy, navy, navy, navy, navy, navy, navy, navy, gold ]

        simbolo = ->(moneda) { moneda == "USD" ? "$" : "L." }

        TipoEnvio.activos.order(:nombre).each do |te|
          filas = Tarifa.where(tipo_envio_id: te.id)
                        .includes(:categoria_precio, :cliente, :proveedor, :sucursal)
                        .to_a
                        .sort_by { |t|
                          nivel = t.cliente_id ? 3 : (t.proveedor_id ? 2 : (t.categoria_precio_id ? 1 : 0))
                          [ nivel, t.categoria_precio&.nombre.to_s.downcase,
                            t.desde_libras.to_f, t.sucursal&.nombre.to_s ]
                        }
          next if filas.empty?

          nombre_servicio = te.codigo.to_s.upcase == te.nombre.to_s.upcase ?
                              te.nombre : "#{te.codigo.to_s.upcase} — #{te.nombre}"

          filas.each do |t|
            aplica = t.cliente&.nombre_completo || t.proveedor&.nombre ||
                     t.categoria_precio&.nombre || "Precio de lista (público)"
            # Las filas que no vienen de su tabla son sobras del arranque del
            # sistema — conviene que las vea marcadas y no mezcladas.
            heredada = t.notas.to_s.start_with?("Backfill") ?
                         "⚠ No venía en tu tabla — quedó del arranque" : ""

            s.add_row [
              nombre_servicio,
              aplica,
              t.sucursal&.nombre || "todas",
              t.desde_libras.to_f,
              t.hasta_libras ? t.hasta_libras.to_f : "en adelante",
              "#{simbolo.(t.moneda)}#{'%.2f' % t.precio_libra}",
              t.minimo_monto ? "#{simbolo.(t.minimo_moneda)}#{'%.2f' % t.minimo_monto_con_isv}" : "—",
              t.minimo_monto ? "#{simbolo.(t.minimo_moneda)}#{'%.2f' % t.minimo_monto}" : "—",
              t.aplica_minimo ? "Sí" : "NO",
              t.incremento_libras ? "por #{t.incremento_libras.to_f} lb" : "peso exacto",
              heredada
            ], style: [ wrapb, wrap, wrap, wrap, wrap, wrap, wrap, gris, wrap, wrap, llenar ]
          end

          s.add_row []
        end

        s.column_widths 24, 26, 16, 11, 13, 14, 18, 14, 14, 13, 30
      end

      # ─────────────────────────────────────────────────────────────
      # Hoja 3 — Etiqueta
      # ─────────────────────────────────────────────────────────────
      wb.add_worksheet(name: "3. Etiqueta") do |s|
        s.add_row [ "Etiqueta de ETIQUETAR — 2.25 x 1.25 pulgadas (Dymo)" ], style: titulo
        s.add_row [ "Los 11 campos que anotaste. Nos dijiste que el tamaño de la etiqueta no cambia y que \"allí es letra pequeña unas y otras grandes\", así que van los 11 con jerarquía de tamaño. Esta hoja queda de referencia: si algo sale mal impreso, marcalo en la última columna." ], style: nota
        s.add_row []
        s.add_row [ "#", "Campo", "Ejemplo", "Tu nota", "¿Sale bien impreso?" ], style: [ navy, navy, navy, navy, gold ]

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

      # ─────────────────────────────────────────────────────────────
      # Hoja 4 — Los cargos que no son flete
      #
      # De los 16 se cargaron 5, los que su propio texto define. Los otros 10
      # necesitan la moneda: la leyenda de colores de su hoja nunca se aplicó a
      # las celdas, así que un "5" no dice si son dólares o lempiras.
      # ─────────────────────────────────────────────────────────────
      wb.add_worksheet(name: "4. Cargos") do |s|
        s.add_row [ "Cargos que no son flete — nos falta la moneda" ], style: titulo
        s.add_row [ "En tu hoja pusiste la leyenda \"precios en $\" y \"precios en lempiras\", pero las celdas de precio quedaron sin colorear. Viendo solo el numero no hay como saber si un 5 son cinco dolares o cinco lempiras, y preferimos preguntarte antes que adivinar: son montos que se le cobran al cliente." ], style: nota
        s.add_row []

        s.add_row [ "YA CARGADOS — estos los dejaste claros en la misma hoja" ], style: wrapb
        s.add_row [ "Cargo", "Precio", "Moneda", "Como lo supimos", "" ], style: navy
        [
          [ "Entrega nacional",           "86.96", "LPS", "El titulo dice L100, y 86.96 mas ISV da L.100.00 exactos" ],
          [ "Compra online",              "1.00",  "USD", "Tu nota: \"ponerlo $1 mas isv\"" ],
          [ "Manejo y gastos de destino", "1.00",  "LPS", "Tu nota: \"ponerlo lps1 mas isv\"" ],
          [ "Flete internacional UPS",    "1.00",  "USD", "El titulo de la fila dice \"$1\"" ],
          [ "Retornado en Miami",         "5.00",  "USD", "Tu nota: \"todo en $\"" ]
        ].each { |r| s.add_row r + [ "" ], style: [ wrapb, wrap, wrap, gris, wrap ] }

        s.add_row []
        s.add_row [ "NOS FALTAN ESTOS — escribi la moneda en la columna amarilla" ], style: wrapb
        s.add_row [ "Cargo", "Valor en tu hoja", "Que anotaste", "Nuestra duda", "MONEDA ($ o LPS)" ],
                  style: [ navy, navy, navy, navy, gold ]
        [
          [ "Cambio de servicio", "5 (titulo dice L100)", "pasarlo a dolares",
            "OJO: hoy el sistema lo tiene en $15 y se cobra SOLO, en nota de debito, cada vez que se factura un paquete al que le cambiaron el servicio. Mientras no confirmes sigue cobrando $15." ],
          [ "Retenido Miami", "5", "pasarlo a dolares", "El 5 ya es dolares, o todavia hay que convertirlo?" ],
          [ "Servicio de entrada y salida", "10 (minimo 5)", "pasarlo a dolares", "Misma duda" ],
          [ "Recolecta Miami", "35 (minimo 35)", "—",
            "Vos mismo pediste que la recolecta fuera por ZONA y no $35 fijos, y asi esta hecho. Dejamos la tabla por zona o la cambiamos a 35 plano?" ],
          [ "Ajuste", "1", "—", "En que moneda, y que ajusta exactamente?" ],
          [ "Entrega local", "1 (titulo dice L1)", "—", "El titulo dice L1 pero no hay nota que lo confirme" ],
          [ "Consolidando en Miami", "1", "—", "En que moneda?" ],
          [ "Flete Mexico", "5 (minimo 6)", "—", "En que moneda?" ],
          [ "Flete", "0", "—", "Este es el flete del paquete, que ya sale de la tabla de tarifas. Lo dejamos fuera; confirmanos si te parece." ],
          [ "Producto ejemplo (y en dolares)", "4 y 10", "—", "Los tomamos como datos de prueba. Confirmanos que no van." ]
        ].each { |r| s.add_row r + [ "" ], style: [ wrapb, wrap, wrap, gris, llenar ] }

        s.column_widths 30, 20, 20, 62, 20
        s.rows[6..].each { |r| r.height = 34 }
      end

      pkg.serialize(destino.to_s)

    puts "  ✓ #{destino.relative_path_from(Rails.root)}"
  end


  desc "Genera el documento completo: historia del proyecto y todas las reglas"
  task historia_pdf: :environment do
    require "prawn"
    require "prawn/table"

    destino = DESTINO.join("historia_y_reglas.pdf")
    FileUtils.mkdir_p(DESTINO)

    pdf = Prawn::Document.new(page_size: "LETTER", margin: [ 50, 45, 45, 45 ])
    fuentes = Rails.root.join("vendor/fonts")
    if File.exist?(fuentes.join("DejaVuSans.ttf"))
      pdf.font_families.update("DejaVu" => {
        normal: fuentes.join("DejaVuSans.ttf").to_s,
        bold: fuentes.join("DejaVuSans-Bold.ttf").to_s
      })
      pdf.font "DejaVu"
    end

      # ── Portada ──
      pdf.fill_color NAVY
      pdf.text "Compras Express Cargo", size: 24, style: :bold
      pdf.fill_color GOLD
      pdf.text "El sistema, de principio a fin", size: 15, style: :bold
      pdf.fill_color GRIS
      MESES_H = %w[enero febrero marzo abril mayo junio julio agosto
                   septiembre octubre noviembre diciembre].freeze
      hoy_h = Date.current
      pdf.text "Historia del proyecto y todas las reglas de negocio  ·  #{hoy_h.day} de #{MESES_H[hoy_h.month - 1]} de #{hoy_h.year}", size: 9.5
      pdf.fill_color "000000"
      pdf.move_down 16

      pdf.fill_color "F8F9FB"
      pdf.fill_rounded_rectangle([ 0, pdf.cursor ], pdf.bounds.width, 92, 5)
      pdf.fill_color "000000"
      pdf.move_down 12
      pdf.indent(14) do
        pdf.text "Para qué es este documento", size: 10.5, style: :bold
        pdf.move_down 3
        pdf.text "Es el recuento completo de lo que se construyó desde el arranque y, sobre todo, " \
                 "de <b>todas las reglas de negocio que el sistema aplica hoy</b>. Muchas salieron de " \
                 "conversaciones sueltas a lo largo de meses. Acá están juntas para que las leas de " \
                 "corrido y nos digas cuáles quedaron mal entendidas.",
                 size: 9.5, leading: 2.5, inline_format: true
      end
      pdf.move_down 20

      p_(pdf, "<b>Cómo leerlo:</b> la parte 1 es el recorrido de un paquete, para ubicarse. La parte 2 son " \
              "las reglas — es la que importa revisar. La parte 3 es la historia por etapas. La parte 4, " \
              "lo que sigue.")

      # ══ PARTE 1 ══
      h1(pdf, "1. El recorrido de un paquete")

      p_(pdf, "Todo el sistema gira alrededor de este flujo. Cada etapa deja registro de <b>quién</b> la " \
              "hizo y <b>cuándo</b>.")

      tabla(pdf,
        [ "#", "Etapa", "Qué pasa" ],
        [
          [ "1", "<b>Pre-alerta</b>", "El cliente avisa desde su portal que viene un paquete. Es opcional: puede llegar sin avisar." ],
          [ "2", "<b>Recepción en Miami</b>", "Llega el camión, se separa por tipo de servicio, se etiqueta y se digita. Acá nace el paquete en el sistema." ],
          [ "3", "<b>Estantería y empaque</b>", "Se acomoda y se mete en las cajas de salida." ],
          [ "4", "<b>Manifiesto</b>", "Se arma el envío hacia Honduras." ],
          [ "5", "<b>Aduana</b>", "Trámite de nacionalización de la carga." ],
          [ "6", "<b>Disponible</b>", "Llega a la sucursal donde el cliente retira." ],
          [ "7", "<b>Pre-factura</b>", "Se calcula lo que se le cobra. Es el paso donde se aplica todo lo de la parte 2." ],
          [ "8", "<b>Factura y pago</b>", "Se emite, se cobra, se genera el recibo." ],
          [ "9", "<b>Entrega</b>", "Se despacha y se entrega al cliente." ]
        ], anchos: [ 22, 118, 347 ])

      h2(pdf, "Quién hace qué")
      tabla(pdf,
        [ "Rol", "Qué le toca" ],
        [
          [ "<b>Digitador Miami</b>", "Etiqueta y digita los paquetes que llegan." ],
          [ "<b>Supervisor Miami</b>", "Supervisa recepción, pre-alertas y re-empaque." ],
          [ "<b>Supervisor Pre-Factura</b>", "Revisa y genera las pre-facturas." ],
          [ "<b>Cajero</b>", "Cobra, emite recibos, maneja la caja del día." ],
          [ "<b>Supervisor Caja</b>", "Supervisa cobros, ventas y notas de débito/crédito." ],
          [ "<b>Entrega y Despacho</b>", "Despacha y entrega en Honduras." ],
          [ "<b>SAC</b>", "Atención al cliente." ],
          [ "<b>Administrador</b>", "Todo, más los catálogos y la configuración." ]
        ], anchos: [ 150, 337 ])

      pdf.start_new_page

      # ══ PARTE 2 ══
      h1(pdf, "2. Las reglas que aplica el sistema")

      pdf.fill_color ROJO
      pdf.text "Esta es la parte a revisar. Si algo acá está mal, se cobra mal.", size: 10, style: :bold
      pdf.fill_color "000000"
      pdf.move_down 10

      h2(pdf, "Los cinco servicios")
      tabla(pdf,
        [ "Código", "Modalidad", "Precio/lb", "Entrega", "Reempaque", "Consolida" ],
        TipoEnvio.activos.order(precio_libra: :desc).map { |t|
          [ "<b>#{t.codigo.to_s.upcase}</b>", t.modalidad.to_s.capitalize,
            "$#{'%.2f' % t.precio_libra}", t.sla.to_s.sub(" dias habiles", " días"),
            t.con_reempaque ? "Sí" : "No", t.consolidable ? "Sí" : "No" ]
        }, anchos: [ 62, 72, 60, 95, 68, 60 ])
      p_(pdf, "CKA y CKM admiten <b>un solo paquete por acción</b>. Si un cliente no elige servicio, se " \
              "procesa como <b>CER</b>.")

      h2(pdf, "Cómo se decide el precio de un paquete")
      p_(pdf, "Gana la regla más específica que aplique. Si no hay ninguna cargada, se usa el precio de lista.")
      tabla(pdf,
        [ "Prioridad", "Regla", "Ejemplo" ],
        [
          [ "1ª", "Precio especial de <b>ese cliente</b> en <b>ese servicio</b>", "A Jorge el marítimo a $1.50" ],
          [ "2ª", "Promoción del <b>proveedor</b>", "Todo lo que venga de Shein" ],
          [ "3ª", "<b>Categoría</b> del cliente", "Mayorista, revendedor, familia" ],
          [ "4ª", "Precio de <b>lista</b>", "El público" ]
        ], anchos: [ 62, 233, 192 ])
      p_(pdf, "Dentro de la regla que gane, se usa el <b>escalón de peso</b> que corresponda. Y si hay una " \
              "tarifa para esa <b>sucursal</b>, esa pisa a la general — por el costo extra de transporte.")

      h2(pdf, "Los cobros mínimos")
      p_(pdf, "Esto es lo que quedó cargado de tu tabla 2026, para el precio de lista:")
      tabla(pdf,
        [ "Servicio", "Mínimo", "Cómo lo aplica" ],
        [
          [ "<b>CER, CKA, CEM, CKM</b>", "L.200 <b>con</b> ISV", "Guarda L.173.91 y al facturar vuelve a dar los L.200 que cobrás." ],
          [ "<b>EXPRESS</b>", "$10 <b>más</b> ISV", "Cobra $10 y el impuesto se suma aparte." ]
        ], anchos: [ 110, 100, 277 ])
      p_(pdf, "El mínimo es <b>por concepto, no por factura</b>: el flete lleva el suyo, la recolecta el suyo.")
      p_(pdf, "Hay dos formas de mínimo y el sistema maneja las dos: <b>por monto</b> (un piso en dinero) y " \
              "<b>por libras</b> (se factura un peso mínimo). Tu tabla trae solo mínimos por monto. La " \
              "categoría <b>Sin Cobro Mínimo</b> no lleva ninguno: cobra el peso real por chico que sea.")

      h2(pdf, "El precio baja según el peso")
      p_(pdf, "CER, CEM y CKM tienen tarifario escalonado — mientras más pesa, más barata la libra. CKA y " \
              "EXPRESS son precio plano. Esto aplica al <b>precio de lista</b>; las categorías tienen un " \
              "precio único.")
      tabla(pdf,
        [ "CER", "$/lb", "CEM", "$/lb", "CKM", "$/lb" ],
        [
          [ "0 – 50 lb",   "4.50", "0 – 3 lb",     "4.50", "0 – 3 lb",      "4.00" ],
          [ "50.5 – 100",  "4.00", "3.5 – 100",    "2.50", "3.5 – 13",      "2.50" ],
          [ "100.5 – 150", "3.75", "100.5 – 200",  "2.20", "13.5 – 100",    "1.90" ],
          [ "150.5 +",     "3.50", "200.5 +",      "2.00", "100.5 – 200",   "1.75" ],
          [ "",            "",     "",             "",     "200.5 +",       "1.65" ]
        ], anchos: [ 90, 45, 92, 45, 100, 45 ])
      p_(pdf, "En <b>Tegucigalpa</b> el CKM de 13.5 a 100 libras cuesta <b>$2.00</b> en vez de $1.90, por el " \
              "costo extra de transporte. Lo aplica el sistema solo, según a dónde va el paquete — el cajero " \
              "no elige nada. Lo mismo con Shein: su marítimo sube de $1.75 a $1.90 en Tegucigalpa.")

      h2(pdf, "Peso: cuál se cobra")
      p_(pdf, "Se compara el <b>peso real</b> contra el <b>peso volumétrico</b> y se cobra el mayor.")
      tabla(pdf,
        [ "Concepto", "Cómo se calcula" ],
        [
          [ "<b>Peso volumétrico</b>", "alto × largo × ancho (en pulgadas) ÷ 166" ],
          [ "<b>Redondeo</b>", "A media libra: si la fracción es menor a .10 baja, entre .10 y .59 va a .50, y de .60 para arriba sube." ],
          [ "<b>Peso a cobrar</b>", "El mayor entre el peso real y el volumétrico." ]
        ], anchos: [ 130, 357 ])
      p_(pdf, "Los cálculos de <b>pie cúbico</b> y <b>metro cúbico</b> que se ven en pantalla son solo " \
              "informativos: no afectan el precio.")

      h2(pdf, "Dinero e impuesto")
      tabla(pdf,
        [ "Regla", "Detalle" ],
        [
          [ "<b>Todos los precios llevan ISV</b>", "El impuesto se aplica <b>una sola vez</b>, al totalizar la factura." ],
          [ "<b>Redondeo de montos</b>", "Half-up al segundo decimal, sobre el resultado final de cada línea. Regla del contador." ],
          [ "<b>Tarifas en dólares</b>", "El precio por libra es en dólares; la factura sale en Lempiras convertida a la tasa." ],
          [ "<b>Tasa de cambio fija</b>", "La define un administrador. Ya no se actualiza sola desde internet." ],
          [ "<b>El mínimo es por concepto</b>", "El flete lleva su mínimo y la recolecta el suyo. No hay un mínimo global de factura." ]
        ], anchos: [ 152, 335 ])

      pdf.start_new_page

      h2(pdf, "Pre-alertas")
      tabla(pdf,
        [ "Regla", "Detalle" ],
        [
          [ "<b>Tracking opcional</b>", "Se puede crear la pre-alerta sin tracking y agregarlo después." ],
          [ "<b>Consolidación</b>", "Solo EXPRESS, CER y CEM. Sin costo adicional. Se pide antes de que llegue a Honduras." ],
          [ "<b>Un paquete por acción</b>", "Las pre-alertas sin consolidar y las de CKA/CKM aceptan un solo paquete." ],
          [ "<b>Vinculación automática</b>", "Cuando el tracking se recibe en Miami, se enlaza solo con su pre-alerta y se le avisa al cliente por correo." ],
          [ "<b>Notas del grupo</b>", "Editables mientras la pre-alerta esté consolidando y ningún paquete haya pasado de aduana." ]
        ], anchos: [ 145, 342 ])

      h2(pdf, "Recepción en Miami")
      tabla(pdf,
        [ "Regla", "Detalle" ],
        [
          [ "<b>Número de recepción</b>", "Correlativo anual por sucursal." ],
          [ "<b>Tracking repetido</b>", "El sistema avisa y ofrece tres caminos: es una actualización, es cambio de servicio, o es un duplicado real (le agrega sufijo A–Z)." ],
          [ "<b>Segundo tracking</b>", "Muchos paquetes traen dos números. El sistema acepta ambos y busca por los dos." ],
          [ "<b>Un tracking, varias cajas</b>", "Se divide en n/N y sale una etiqueta por caja." ],
          [ "<b>Sesión por servicio</b>", "El digitador elige el tipo una vez y vale para todo el lote." ],
          [ "<b>Retención</b>", "Al retener un paquete es obligatorio indicar el motivo." ]
        ], anchos: [ 152, 335 ])

      h2(pdf, "Las cinco clases de nota")
      tabla(pdf,
        [ "Nota", "Para qué" ],
        [
          [ "<b>Permanentes del cliente</b>", "Siempre aplican. Separadas por área: Miami, Caja, Honduras y SAC — cada quien ve la suya." ],
          [ "<b>Internas</b>", "Entre el equipo. El cliente no las ve." ],
          [ "<b>Al cliente</b>", "Cualquier área le escribe al cliente. Hay plantillas para lo que se repite." ],
          [ "<b>De consolidación</b>", "Vienen de la pre-alerta consolidada." ],
          [ "<b>Especiales</b>", "Las instrucciones que el cliente escribió en su pre-alerta." ]
        ], anchos: [ 148, 339 ])
      p_(pdf, "Las instrucciones del cliente además <b>se vuelven tareas</b> con casilla de verificación, " \
              "para que no se pierdan en un cuadro de texto. Al marcarlas queda registrado quién y cuándo.")

      h2(pdf, "Facturación")
      tabla(pdf,
        [ "Regla", "Detalle" ],
        [
          [ "<b>Camino único</b>", "Pre-factura → factura → pago → recibo. No se puede saltar pasos." ],
          [ "<b>Cargos automáticos</b>", "La recolecta y el cambio de servicio se agregan solos a la pre-factura." ],
          [ "<b>Cambio de servicio</b>", "Genera nota de débito al facturar. El monto es ajustable en la pre-factura." ],
          [ "<b>Prepagado en Miami</b>", "Si pagó allá, en Honduras solo se hace una factura simbólica de $1 más impuesto." ],
          [ "<b>Tareas abiertas</b>", "Un paquete con tareas pendientes no avanza de etapa." ],
          [ "<b>El precio sale bloqueado</b>", "En la pre-factura nadie edita el monto suelto. Precio, peso, descuento y quitar una línea piden el PIN de un supervisor, y queda registrado quién autorizó y por qué." ],
          [ "<b>Descuento a la vista</b>", "El descuento es un campo propio y sale impreso en la factura, en monto o en porcentaje. El ISV se calcula sobre el neto, después del descuento." ],
          [ "<b>Emitir una nota lleva dos firmas</b>", "Las notas de débito y crédito se arman libres, pero al emitirlas —que es cuando cambia el saldo del cliente— piden el PIN de un supervisor distinto de quien la creó." ]
        ], anchos: [ 140, 347 ])

      h2(pdf, "Entrega Personal")
      tabla(pdf,
        [ "Regla", "Detalle" ],
        [
          [ "<b>Pantalla aparte</b>", "No se mezcla con el etiquetado normal." ],
          [ "<b>Tracking automático</b>", "Formato EP-AÑO-SUCURSAL-PROVEEDOR-NÚMERO, correlativo anual." ],
          [ "<b>Proveedor ≠ Driver</b>", "El proveedor es la empresa que lo mandó; el driver es la persona que lo trajo." ],
          [ "<b>Se paga en los dos lados</b>", "En Miami o en Honduras, el operario elige." ],
          [ "<b>Sigue el flujo normal</b>", "Va al manifiesto y pasa por aduana como cualquier otro." ]
        ], anchos: [ 152, 335 ])

      pdf.start_new_page

      h2(pdf, "Las cuatro etiquetas")
      tabla(pdf,
        [ "Operación", "Tamaño", "Se pega" ],
        [
          [ "<b>Etiquetar</b>", "2.25 × 1.25 in (Dymo)", "Una por paquete. Si el tracking se divide en 5, van 5." ],
          [ "<b>Manifiesto</b>", "4 × 6 in (FreeX)", "Una por caja o paquete." ],
          [ "<b>Pre-factura</b>", "4 × 6 in (FreeX)", "Por paquete. Un paquete puede llevar varios tracking." ],
          [ "<b>Manifiesto nacional</b>", "4 × 6 in (FreeX)", "Por fuera. Lleva varias pre-facturas." ]
        ], anchos: [ 130, 118, 239 ])
      p_(pdf, "Solo se rediseñó la de <b>Etiquetar</b>. Lleva código de barras del número de recepción — " \
              "antes no había nada escaneable y el tracking se tecleaba a mano.")

      h2(pdf, "Caja y entregas")
      tabla(pdf,
        [ "Regla", "Detalle" ],
        [
          [ "<b>Apertura y cierre</b>", "La caja se abre y se cierra por día, con su resumen." ],
          [ "<b>Pagos ligados a la caja</b>", "Todo pago se asocia solo a la caja abierta del día." ],
          [ "<b>Entrega</b>", "Se registra a quién se le entregó, con su identidad." ],
          [ "<b>Estados de entrega</b>", "Facturado → en reparto → entregado, con transiciones controladas." ]
        ], anchos: [ 152, 335 ])

      # ══ PARTE 3 ══
      h1(pdf, "3. Cómo se fue construyendo")

      p_(pdf, "Cada etapa cerró un pedazo del negocio. Las que dicen “en curso” son las de estas semanas.")

      tabla(pdf,
        [ "Etapa", "Qué dejó funcionando", "Estado" ],
        [
          [ "<b>0. Fundación</b>", "Acceso al sistema, los 8 roles, y los dos portales: el del equipo y el del cliente.", "Listo" ],
          [ "<b>1. Miami</b>", "Etiquetar y manifiestos. El corazón de la operación.", "Listo" ],
          [ "<b>2. Pre-alertas</b>", "El cliente avisa desde su portal; se vincula sola al recibir en Miami.", "Listo" ],
          [ "<b>3. Facturación</b>", "Pre-factura, factura, pago y recibo. Notas de débito y crédito, cotizaciones, financiamientos, PDFs y correos.", "Listo" ],
          [ "<b>4. Caja y entregas</b>", "La caja del día y el despacho al cliente.", "Listo" ],
          [ "<b>5. Tareas y reempaque</b>", "Checklist de operaciones especiales y registro del reempaque con sus medidas.", "Listo" ],
          [ "<b>5b. Recepción</b>", "Numeración anual, flujo guiado para tracking repetido, segundo tracking.", "Listo" ],
          [ "<b>5c. Detalle y WR</b>", "Warehouse Receipt, sucursales, notas por categoría, catálogo de proveedores, bitácora de cambios.", "Listo" ],
          [ "<b>6. Dashboard</b>", "Indicadores del día y accesos rápidos.", "Parcial" ],
          [ "<b>10. Contexto</b>", "La franja de tareas y notas del cliente mientras se captura.", "Listo" ],
          [ "<b>11. Tarifas</b>", "Todo lo de la parte 2: precios, mínimos, escalones y la moneda. Tu tabla de precios 2026 ya está cargada.", "Listo" ],
          [ "<b>12. Escaneo al empacar</b>", "Pre-etiqueta de caja y verificación al empacar.", "Planificada" ],
          [ "<b>13. Autorizaciones</b>", "El precio bloqueado en la pre-factura, el PIN del supervisor, el descuento como campo propio y la pantalla donde se revisa todo lo autorizado.", "Listo" ]
        ], anchos: [ 118, 300, 69 ])

      pdf.start_new_page

      h2(pdf, "Lo que falta construir")
      tabla(pdf,
        [ "Etapa", "Qué sería" ],
        [
          [ "<b>Marketing</b>", "Correos, WhatsApp y SMS a clientes. Hoy los botones están ocultos porque no hacen nada." ],
          [ "<b>Inventario</b>", "Productos y existencias." ],
          [ "<b>Fotos de paquetes</b>", "Tomar foto al recibir y mandársela al cliente." ],
          [ "<b>Reportes</b>", "El módulo de reportes propiamente dicho." ],
          [ "<b>Escaneo al empacar</b>", "Lo que pediste que quedara planificado: se escanea cada paquete al meterlo a la caja y el sistema pita si el servicio no concuerda. Al armar el manifiesto se jalan las cajas ya empacadas." ],
          [ "<b>Los 10 cargos que faltan</b>", "De los 16 que no son flete ya cargamos 5. Los otros 10 esperan a que nos digas la moneda: en tu hoja los numeros no dicen si son dolares o lempiras. Estan en la hoja 4 del Excel." ]
        ], anchos: [ 130, 357 ])

      # ══ PARTE 4 ══
      h1(pdf, "4. Decisiones que conviene que conozcas")

      p_(pdf, "Cosas que se resolvieron de una manera y no de otra, con el motivo. Si alguna no te cuadra, " \
              "se puede cambiar.")

      tabla(pdf,
        [ "Decisión", "Por qué" ],
        [
          [ "<b>Los catálogos los manejás vos</b>", "Servicios, tarifas, proveedores, motivos de retención y plantillas de notas tienen su pantalla para que los crees y edites sin pedírnoslo." ],
          [ "<b>El driver es texto libre</b>", "Cambia en cada entrega. Un catálogo ahí sería estorbo, al revés que con el proveedor." ],
          [ "<b>Los mínimos se guardan sin impuesto</b>", "Vos los conocés con el impuesto adentro (L.200), pero el sistema necesita el neto para no sumarlo dos veces. La pantalla te pregunta como vos lo cobrás." ],
          [ "<b>La empresa transportadora se hereda</b>", "Sale del manifiesto en el que va el paquete, no se guarda repetida." ],
          [ "<b>La cantidad de cajas se pregunta al imprimir</b>", "Lo revisaste y quedó así: es parte del proceso de impresión, no del formulario." ],
          [ "<b>El valor a pagar es referencia</b>", "Lo que se ve en Entrega Personal orienta al operario; el cobro de verdad se calcula en la pre-factura." ]
        ], anchos: [ 165, 322 ])

      h1(pdf, "5. Lo que falta que decidas")

      tabla(pdf,
        [ "#", "Qué se necesita" ],
        [
          [ "1", "<b>Revisar los precios que se cargaron</b> de tu tabla. Están en la hoja 2 del Excel, leídos directo de la base — es literalmente lo que va a cobrar el sistema." ],
          [ "2", "¿Hace falta todavía un <b>mínimo en libras</b> para CEM y CKM? Tu tabla trae el mínimo en dinero pero no el de libras." ],
          [ "3", "<b>CKM está en dos reglas que se contradicen</b>: es de la serie CK (mínimo L.200) y además es marítimo (mínimo en libras). En tu tabla le pusiste L.173.91, así que cargamos ese. ¿Confirmás?" ],
          [ "4", "<b>Regular y VIP</b> no aparecen en tu tabla y tienen 8 clientes asignados. ¿A cuál de las categorías nuevas los pasamos?" ],
          [ "5", "Las <b>categorías no bajan de escalón</b>: un Clientes Amigos con 200 lb de CER paga $4.20/lb y el público paga $3.50. Es literal a tu tabla — decinos si es lo que querés." ],
          [ "6", "<b>A quiénes les asignamos PIN de autorización.</b> Pueden tenerlo Administrador, Supervisor Caja, Supervisor Pre-Factura y Supervisor de Servicio al Cliente." ],
          [ "7", "<b>Imprimir una etiqueta y revisar que no se corte nada</b>, sobre todo en un paquete que traiga tercero y driver a la vez — es el que más campos lleva." ],
          [ "8", "Confirmar la <b>lista de proveedores</b> de entrega personal para dejarlos precargados." ]
        ], anchos: [ 22, 465 ])

      pdf.move_down 14
      pdf.stroke_color "D4D4D4"
      pdf.stroke_horizontal_rule
      pdf.stroke_color "000000"
      pdf.move_down 6
      pdf.fill_color GRIS
      pdf.text "Las reglas de la parte 2 están todas implementadas y con pruebas automáticas que las verifican " \
               "en cada cambio. Detalle técnico en docs/05 y docs/06 del repositorio.", size: 8
      pdf.fill_color "000000"

      pdf.number_pages "<page> / <total>", at: [ pdf.bounds.right - 60, -22 ], size: 8, color: GRIS

    pdf.render_file destino.to_s
    puts "  ✓ #{destino.relative_path_from(Rails.root)}"
  end

  desc "Regenera todos los entregables"
  task entregables: %i[resumen_pdf historia_pdf preguntas_xlsx]
end
