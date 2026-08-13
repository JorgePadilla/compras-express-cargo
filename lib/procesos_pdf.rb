require Rails.root.join("lib/pdf_diagrama")

# Los diagramas de proceso, para que Yusef vea cómo funciona la operación y
# **hasta dónde llega lo construido**.
#
# Cada paso es un hash, no dibujo suelto. Eso deja **probar el diagrama contra
# el sistema**: hay un test que verifica que cada ruta que el diagrama nombra
# exista de verdad, y que cada estado esté en el enum de `Paquete`. Un diagrama
# que apunta a una pantalla que ya no existe es peor que no tenerlo.
class ProcesosPdf
  include PdfDiagrama

  # `actor`  → :persona (alguien aprieta un botón) · :sistema (pasa solo) ·
  #            :fisico (pasa en el mundo, no en el sistema)
  # `existe` → false marca los pasos que están en el diseño pero no en ninguna
  #            pantalla. Es lo que Jorge pidió ver.
  # A7-02: el dibujo arrancaba en el portal del cliente, y ese es el canal
  # **minoritario**. Yusef, viéndolo:
  #
  #   > "El cliente solo hace ni... que **30, 40% de las prealertas**."
  #
  # Y ordenó las entradas de una forma que conviene respetar tal cual:
  #
  #   > "Uno lo ve entrada, proceso, salida. Donde nace el paquete, esa es la
  #   >  entrada de nuestro sistema. Veo que hay prealerta, escaneándolo en
  #   >  Miami, y hay otra entrada que es una **digitación manual**, que no
  #   >  necesariamente en Miami, puede ser desde aquí. Esas son las tres
  #   >  entradas."
  CAMINO_MIAMI = [
    { titulo: "Pre-alerta", quien: "el cliente en su portal, o un admin por él",
      actor: :persona, ruta: "new_cuenta_pre_alerta_path", existe: true },
    { titulo: "Nace el paquete", quien: "el sistema, solo",
      actor: :sistema, estado: "pre_alerta_estado", existe: true },
    { titulo: "Llega el camión a Miami", quien: "el courier",
      actor: :fisico, existe: true },
    { titulo: "Etiquetar", quien: "digitador de Miami",
      actor: :persona, ruta: "etiquetar_path", estado: "recibido_miami", existe: true },
    # Acá NO va el paso de empacar. Jorge, 2026-08-10: "hasta que terminemos
    # con etiquetas y entrega personal hagamos preguntas de empaque". El estado
    # `empacado` existe en el enum pero nadie lo asigna, así que el paquete pasa
    # de etiquetado directo al manifiesto — el diagrama muestra eso, que es lo
    # que hoy pasa de verdad. Vuelve como sección propia cuando toque.
    { titulo: "Manifiesto", quien: "supervisor de Miami",
      actor: :persona, ruta: "manifiestos_path", estado: "enviado_honduras", existe: true }
  ].freeze

  # A7-01: **la pre-factura va ANTES de la bodega**, y el dibujo lo tenía al
  # revés. Yusef lo corrigió en la revisión del 2026-08-12:
  #
  #   > "Bodega Honduras va **después** de prefactura."
  #
  # Y el porqué, que es lo que hace que no sea negociable:
  #
  #   > **Jorge:** "Yo pensé que se iba a enviar primero y luego en el punto se
  #   >  hacía la prefactura. ¿Por qué no se hace la prefactura en San Pedro?"
  #   > **Yusef:** "Porque **aquí tengo el personal para eso**. En Tegucigalpa no
  #   >  tengo, no voy a tener otra persona haciéndolo."
  #
  # No es preferencia de orden: la pre-factura se hace en San Pedro porque el
  # personal de pre-factura existe solo ahí.
  #
  # El paso de pre-factura ya **no lleva `estado`**: `pre_facturado` existe en el
  # sistema pero es consecuencia de emitir el documento, no un estado que alguien
  # ponga (A7-11).
  CAMINO_HONDURAS = [
    { titulo: "Aduana", quien: "hoy se cambia el estado a mano",
      actor: :persona, estado: "en_aduana", existe: false },
    { titulo: "Pre-factura", quien: "cajero, en San Pedro",
      actor: :persona, ruta: "pre_facturas_path", existe: true },
    { titulo: "Bodega en Honduras", quien: "hoy se cambia el estado a mano",
      actor: :persona, estado: "disponible_entrega", existe: false },
    { titulo: "Factura", quien: "cajero",
      actor: :persona, ruta: "ventas_path", existe: true },
    { titulo: "Pago", quien: "cajero",
      actor: :persona, ruta: "recibos_path", estado: "facturado", existe: true },
    { titulo: "Entrega", quien: "despacho",
      actor: :persona, ruta: "entregas_path", estado: "entregado", existe: true },
    { titulo: "Firma y foto", quien: "nadie lo ha pedido todavía",
      actor: :persona, existe: false }
  ].freeze

  # El ejemplo de tracking de Entrega Personal. Va acá arriba porque hay un test
  # que lo confronta contra `Paquete#generate_ep_tracking`: la sucursal del
  # tracking es la **de retiro** y entra con su `codigo_ep` (`SSM`), no con su
  # `codigo` (`SAM`). Un ejemplo mal armado, en un formato que Yusef definió él
  # mismo, es justo la clase de mentira que este PR existe para evitar.
  EJEMPLO_TRACKING_EP = "EP-2026-SSM-DRV-000042".freeze

  # Los ocho desvíos. `engancha` dice dónde se pega al camino principal — sin
  # eso un flujo suelto no se entiende.
  ALTERNATIVOS = [
    # A7-02. Va primero porque es lo primero que Yusef corrigió del dibujo: el
    # camino principal arranca en la pre-alerta del cliente, y ese canal es el
    # minoritario. Sin esto el diagrama describe el 30-40% de la operación.
    { nombre: "Por dónde entra un paquete al sistema",
      cuando: "El camino principal dibuja la pre-alerta del cliente, pero \"el cliente solo hace ni... que 30, 40% de las prealertas\" (Yusef).",
      engancha: "Las tres desembocan en el mismo paquete: de ahí en adelante el camino es uno solo.",
      pasos: [
        { titulo: "Pre-alerta", quien: "el cliente o un admin por él", actor: :persona,
          ruta: "new_cuenta_pre_alerta_path", existe: true },
        { titulo: "Escaneo en Miami", quien: "digitador, con la pistola", actor: :persona,
          ruta: "etiquetar_path", existe: true },
        { titulo: "Digitación manual", quien: "cuando en Miami se les escapó escanear",
          actor: :persona, ruta: "etiquetar_path", existe: true }
      ],
      notas: [
        "Si el tracking escaneado coincide con una pre-alerta, el sistema los amarra solo.",
        "Si no coincide con ninguna, el paquete nace ahí mismo.",
        "La digitación manual es la etiqueta local que se hace en San Pedro cuando en Miami no se escaneó."
      ] },
    { nombre: "Entrega Personal",
      cuando: "El paquete llega en mano al mostrador de Miami, sin tracking del courier: un driver privado, un Uber, alguien que lo trajo. No hubo pre-alerta.",
      engancha: "Entra directo en «Etiquetar» y de ahí sigue el camino de siempre.",
      pasos: [
        { titulo: "Llega en mano", quien: "el que lo trae", actor: :fisico, existe: true },
        { titulo: "Entrega Personal", quien: "digitador de Miami", actor: :persona,
          ruta: "new_entrega_personal_path", existe: true },
        { titulo: "El sistema inventa el tracking", quien: EJEMPLO_TRACKING_EP,
          actor: :sistema, existe: true },
        { titulo: "Sigue como cualquier paquete", quien: "manifiesto, aduana, entrega",
          actor: :sistema, estado: "recibido_miami", existe: true }
      ],
      notas: [ "El tracking lo arma el sistema: año, código de la sucursal <b>donde el cliente lo va a retirar</b>, " \
               "código del proveedor o del driver, y un correlativo anual.",
               "Si se cobró en Miami («prepagado»), la pre-factura no cobra el flete: sale una línea simbólica de $1 que el cajero ajusta." ] },

    { nombre: "Consolidación",
      cuando: "El cliente quiere que varios paquetes viajen como uno. Solo en EXPRESS, CER y CEM, y sin costo.",
      engancha: "No mueve al paquete de estado. Es una operación sobre la pre-alerta, no sobre el pipeline.",
      pasos: [
        { titulo: "El cliente la pide", quien: "marca «consolidar» al crear la pre-alerta",
          actor: :persona, ruta: "new_cuenta_pre_alerta_path", existe: true },
        { titulo: "Va sumando paquetes", quien: "el cliente, en su portal",
          actor: :persona, ruta: "cuenta_pre_alertas_path", existe: true },
        { titulo: "Finaliza", quien: "solo el cliente puede cerrarla",
          actor: :persona, existe: true },
        { titulo: "Queda cerrada", quien: "ya no se le agrega ni se le saca nada",
          actor: :sistema, existe: true }
      ],
      notas: [ "Se puede mover un paquete entre pre-alertas hasta que llega a aduana. De ahí en adelante, no.",
               "El equipo puede editar una consolidación cerrada; el cliente no." ] },

    { nombre: "Reempaque",
      cuando: "Se saca el producto de su caja original y se empaca más chico, para que el volumétrico baje y el cliente pague menos.",
      engancha: "Ocurre en Miami, después de etiquetar. No cambia el estado del paquete.",
      pasos: [
        { titulo: "Se abre y se mide de nuevo", quien: "Miami", actor: :fisico, existe: true },
        { titulo: "Se anota el reempaque", quien: "cualquier usuario", actor: :persona,
          ruta: "paquetes_path", existe: true },
        { titulo: "El sistema recalcula", quien: "peso volumétrico y peso a cobrar",
          actor: :sistema, existe: true }
      ],
      notas: [ "Guarda las medidas de antes y de después, así que el ahorro queda registrado." ] },

    { nombre: "Recolecta",
      cuando: "El cliente pide que le vayan a traer el paquete. Se cobra por zona.",
      engancha: "Es un cargo que se suma solo a la pre-factura.",
      pasos: [
        { titulo: "El cliente la pide", quien: "por teléfono o en el mostrador",
          actor: :fisico, existe: true },
        { titulo: "Se marca en el paquete", quien: "cajero, con la zona",
          actor: :persona, ruta: "paquetes_path", existe: true },
        { titulo: "La pre-factura la cobra sola", quien: "línea automática",
          actor: :sistema, ruta: "pre_facturas_path", existe: true }
      ],
      notas: [ "Las zonas y sus montos se cargan desde el catálogo, no están en el código." ] },

    { nombre: "Retención",
      cuando: "Algo detiene el paquete: falta un documento, hay una duda de aduana, el cliente debe.",
      engancha: "Sale del camino desde cualquier punto y vuelve al mismo lugar.",
      pasos: [
        { titulo: "Se retiene", quien: "con motivo obligatorio",
          actor: :persona, ruta: "paquetes_path", estado: "retenido", existe: true },
        { titulo: "Se resuelve", quien: "el equipo", actor: :fisico, existe: true },
        { titulo: "Vuelve al camino", quien: "se le devuelve el estado que tenía",
          actor: :persona, existe: true }
      ],
      notas: [ "El sistema no deja retener sin decir por qué: o se elige un motivo o se escribe la razón." ] },

    { nombre: "Cambio de servicio",
      cuando: "El paquete se ingresó con un servicio y era otro. Por ejemplo entró como aéreo y va marítimo.",
      engancha: "Se pide al etiquetar, y el cobro aparece en la pre-factura.",
      pasos: [
        { titulo: "Se marca al etiquetar", quien: "digitador de Miami",
          actor: :persona, ruta: "etiquetar_path", existe: true },
        { titulo: "La pre-factura cobra L.100", quien: "línea automática",
          actor: :sistema, ruta: "pre_facturas_path", existe: true },
        { titulo: "Al facturar sale una nota de débito", quien: "el sistema la crea",
          actor: :sistema, ruta: "notas_debito_path", existe: true }
      ],
      notas: [ "Si fue error del equipo, un supervisor lo quita con su PIN antes de facturar.",
               "Después de facturar ya no: eso se corrige con una nota de crédito." ] },

    # Abanico, no cadena: las tres son excluyentes. Dibujadas una debajo de la
    # otra decían que un paquete devuelto después se destruye y después se anula.
    { nombre: "Retorno, desecho y anulación", forma: :abanico,
      cuando: "El paquete no va a llegar a su destino: se devuelve al proveedor, se destruye, o la operación se cancela.",
      engancha: "Son salidas del camino, y son <b>una o la otra</b>. Un paquete puede caer ahí desde cualquier punto.",
      pasos: [
        { titulo: "El paquete sale del camino", quien: "desde cualquier punto",
          actor: :fisico, existe: true },
        { titulo: "Retornado", quien: "se devuelve al proveedor", actor: :persona,
          ruta: "paquetes_path", estado: "retornado", existe: true },
        { titulo: "Desechado", quien: "se destruye", actor: :persona,
          ruta: "paquetes_path", estado: "desechado", existe: true },
        { titulo: "Anulado", quien: "la operación se cancela", actor: :persona,
          ruta: "paquetes_path", estado: "anulado", existe: true }
      ],
      notas: [ "El sistema no los cuenta como «retroceso»: son rutas alternativas válidas, no un paso atrás." ] },

    { nombre: "Notas de débito y de crédito", forma: :abanico,
      cuando: "Hay que cobrar algo de más o devolver algo, después de que la factura ya salió.",
      engancha: "Cuelgan de una factura ya emitida. Se emite <b>la que corresponda</b>, no las dos.",
      pasos: [
        { titulo: "Existe una factura", quien: "ya emitida", actor: :sistema,
          ruta: "ventas_path", existe: true },
        { titulo: "Nota de débito", quien: "se le cobra de más al cliente", actor: :persona,
          ruta: "notas_debito_path", existe: true },
        { titulo: "Nota de crédito", quien: "se le devuelve al cliente", actor: :persona,
          ruta: "notas_credito_path", existe: true }
      ],
      notas: [ "La de cambio de servicio la crea el sistema solo al facturar; el cajero decide cuándo emitirla." ] }
  ].freeze

  # Las preguntas. Siguen la numeración del PDF de servicios, que llegó hasta
  # RP-29, así que el próximo documento arranca en RP-31.
  #
  # **Solo se pregunta por el módulo en el que estamos.** Jorge, 2026-08-11:
  # "la única pregunta válida ahorita es la 30 porque no hemos llegado a los
  # otros módulos donde están las otras preguntas". El documento sigue
  # *mostrando* los huecos de más adelante —firma y foto al entregar, el pago
  # completo, el manifiesto que no revisa tareas— porque para eso se dibujó;
  # lo que no hace es pedirle a Yusef que los decida antes de tiempo.
  #
  # Las que se sacaron, para cuando toque:
  #   · firma o foto al entregar        → cuando se arme el módulo de entregas
  #   · tareas pendientes vs manifiesto → cuando se arme el de manifiestos
  #   · entregar con pago parcial       → cuando se arme el de caja
  PREGUNTAS = [
    { numero: "RP-30", clave: :aduana, titulo: "Aduana y bodega: hoy se cambia el estado a mano",
      cuerpo: "Entre que sale el manifiesto y que el paquete queda listo para facturar, <b>no hay pantalla</b>. " \
              "Alguien entra a la ficha del paquete y le cambia el estado. Es el hueco más grande que tiene el sistema.",
      opciones: [ "Necesitamos una pantalla para recibir el manifiesto completo de un golpe",
                  "Está bien cambiarlo paquete por paquete",
                  "Que se marque solo cuando llega el manifiesto" ] }
  ].freeze

  # Los símbolos que el documento usa **de verdad**. No hay rombo de decisión:
  # ningún flujo se parte según una condición, y los que se bifurcan —retorno,
  # notas— son alternativas, no una pregunta. Explicar un símbolo que no
  # aparece en ninguna hoja confunde más de lo que ayuda.
  SIMBOLOS = [
    [ "Caja de borde entero", "Un paso que ya existe en el sistema" ],
    [ "Caja celeste", "Lo hace el sistema solo, sin que nadie apriete nada" ],
    [ "Caja de borde punteado", "Un paso del proceso que <b>todavía no tiene pantalla</b>" ],
    [ "Varias cajas colgando de una", "Alternativas: pasa una <b>o</b> la otra, nunca las dos" ],
    [ "Texto chiquito adentro", "Quién lo hace, y en qué estado queda el paquete" ]
  ].freeze

  ANCHO_CAJA = 200
  SALTO = 78

  def render = construir.render
  def render_file(ruta) = construir.render_file(ruta)

  # Todos los pasos de todos los flujos, para que el test los recorra.
  def todos_los_pasos
    CAMINO_MIAMI + CAMINO_HONDURAS + ALTERNATIVOS.flat_map { |f| f[:pasos] }
  end

  def huecos
    todos_los_pasos.reject { |p| p[:existe] }
  end

  private

  def construir
    pdf = documento

    secciones = [ method(:portada), method(:pagina_miami), method(:pagina_honduras) ]
    secciones += ALTERNATIVOS.map { |f| ->(doc) { pagina_alternativo(doc, f) } }
    secciones << method(:pagina_preguntas)

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
    pdf.text "Cómo funciona la operación", size: 15, style: :bold
    pdf.fill_color GRIS
    pdf.text "De la pre-alerta a la entrega  ·  #{fecha_larga}", size: 9.5
    pdf.fill_color "000000"
    pdf.move_down 16

    tarjeta(pdf, 74)
    pdf.move_down 12
    pdf.indent(14) do
      p_(pdf, "Este documento dibuja el camino que recorre un paquete y <b>marca dónde se " \
              "termina lo que está construido</b>. Los pasos con borde punteado son los que " \
              "todavía no tienen pantalla.", size: 9.5)
      p_(pdf, "Al final hay #{frase_preguntas}. Marcá la casilla con una X y mandá la foto.", size: 9.5)
    end
    pdf.move_down 24

    h2(pdf, "Cómo leer los dibujos")
    pdf.move_down 6
    leyenda(pdf, pdf.cursor)

    pdf.move_down 14
    tabla(pdf, [ "Símbolo", "Qué significa" ], SIMBOLOS.map(&:dup), anchos: [ 170, 352 ])
  end

  def pagina_miami(pdf)
    h1(pdf, "En Miami")
    p_(pdf, "Desde que el cliente avisa que viene un paquete hasta que sale el manifiesto.")

    y = pdf.cursor - 10
    cajas = columna(pdf, CAMINO_MIAMI, x: 60, y: y)

    nota(pdf, 290, cajas[3][:y] - 4,
         "Si el tracking coincide con una pre-alerta, el sistema los amarra solo y le avisa al cliente por correo.", ancho: 180)
    nota(pdf, 290, cajas[4][:y] - 4,
         "También entra acá el paquete que llega en mano, sin pre-alerta: es la hoja de Entrega Personal.", ancho: 180)

    pdf.move_cursor_to cajas.last[:y] - cajas.last[:alto] - 30
    h2(pdf, "Una cosa que conviene saber")
    # Se queda como dato, sin casilla: el módulo de manifiestos todavía no se
    # arma, así que no es momento de que Yusef lo decida.
    p_(pdf, "Cuando sale el manifiesto, el sistema mueve <b>todos los paquetes de un golpe</b>. " \
            "Y no revisa si alguno tiene tareas pendientes — a diferencia de la pre-factura, que sí las revisa. " \
            "Lo dejamos anotado para cuando toque armar esa pantalla.")
  end

  def pagina_honduras(pdf)
    h1(pdf, "En Honduras")
    p_(pdf, "Desde que el manifiesto sale de Miami hasta que el paquete queda en manos del cliente.")

    y = pdf.cursor - 10
    cajas = columna(pdf, CAMINO_HONDURAS, x: 60, y: y, alto_caja: 40, salto: 62)

    nota(pdf, 290, cajas[0][:y] - 4,
         "Acá está el hueco más grande: entre el manifiesto y la pre-factura no hay ninguna pantalla. " \
         "Alguien entra a la ficha del paquete y le cambia el estado a mano.", ancho: 180)
    nota(pdf, 290, cajas[4][:y] - 4,
         "El paquete queda listo para entregar solo con el pago COMPLETO. Con un abono parcial no aparece en entregas.", ancho: 180)
    nota(pdf, 290, cajas[6][:y] - 4,
         "Se guarda quién recibió y su identidad, pero no hay firma ni foto.", ancho: 180)
  end

  def pagina_alternativo(pdf, flujo)
    h1(pdf, flujo[:nombre])
    p_(pdf, "<b>Cuándo:</b> #{flujo[:cuando]}")
    p_(pdf, "<b>Dónde se pega al camino principal:</b> #{flujo[:engancha]}")

    y = pdf.cursor - 14
    cajas = if flujo[:forma] == :abanico
      bifurcacion(pdf, flujo[:pasos], y)
    else
      columna(pdf, flujo[:pasos], x: 60, y: y, alto_caja: 42, salto: 66)
    end

    # Las notas van pegadas abajo del dibujo. Fijarlas a una altura constante
    # dejaba media hoja en blanco en los flujos de tres pasos.
    pdf.move_cursor_to cajas.map { |c| c[:y] - c[:alto] }.min - 34
    flujo[:notas].each { |n| p_(pdf, "· #{n}") }
  end

  # El primer paso es el tronco; los demás son las alternativas.
  def bifurcacion(pdf, pasos, y)
    tronco_paso, *ramas_pasos = pasos
    ancho_tronco = 220
    tronco = dibujar_paso(pdf, tronco_paso, (ANCHO_UTIL - ancho_tronco) / 2.0, y, ancho_tronco, 44)

    ramas = abanico(pdf, ramas_pasos.map { |p| ->(x, yy, ancho, alto) { dibujar_paso(pdf, p, x, yy, ancho, alto) } },
                    y: y - 44 - 46, alto: 52)
    bifurcar(pdf, tronco, ramas)

    [ tronco ] + ramas
  end

  # El documento escribe los números con letra. Como la cantidad de preguntas
  # sale de la constante, el texto tiene que salir de ahí también: decía "cinco"
  # cuando ya eran cuatro, y al quedar una sola decía "hay una preguntas".
  NUMEROS = %w[cero una dos tres cuatro cinco seis siete ocho nueve diez].freeze

  def en_letras(n) = NUMEROS.fetch(n, n.to_s)

  def frase_preguntas
    PREGUNTAS.one? ? "una pregunta" : "#{en_letras(PREGUNTAS.size)} preguntas"
  end

  def pagina_preguntas(pdf)
    h1(pdf, "Lo que necesitamos que decidas")
    p_(pdf, PREGUNTAS.one? ? "Una pregunta que sale de los dibujos de atrás. Marcá con una X." :
                             "#{frase_preguntas.capitalize} que salen de los dibujos de atrás. Marcá con una X.")

    PREGUNTAS.each do |q|
      pregunta(pdf, q[:numero], q[:titulo])
      p_(pdf, q[:cuerpo])
      q[:opciones].each { |o| opcion(pdf, o) }
      opcion(pdf, "Otro:")
      linea(pdf)
    end

    espacio_para_anotar(pdf)
  end

  # Renglones libres al final. Con una sola pregunta la hoja queda casi vacía, y
  # este documento se contesta escribiendo encima: el espacio en blanco vale más
  # que el espacio en blanco sin renglones.
  RENGLONES_LIBRES = 6

  def espacio_para_anotar(pdf)
    pdf.move_down 18
    h2(pdf, "Cualquier otra cosa que quieras anotar")
    p_(pdf, "Si algo del proceso no es como lo dibujamos, escribilo acá.")
    RENGLONES_LIBRES.times { linea(pdf); pdf.move_down 8 }
  end

  # Dibuja una cadena vertical de pasos y las flechas entre ellos.
  # Devuelve las cajas, para poder colgarles notas al costado.
  def columna(pdf, pasos, x:, y:, ancho: ANCHO_CAJA, alto_caja: PdfDiagrama::ALTO_CAJA, salto: SALTO)
    cajas = []
    cursor = y

    pasos.each_with_index do |paso, i|
      caja_actual = dibujar_paso(pdf, paso, x, cursor, ancho, alto_caja)
      flecha(pdf, cajas.last[:abajo], caja_actual[:arriba]) if i.positive?
      cajas << caja_actual
      cursor -= salto
    end

    cajas
  end

  # Un paso, del color que le toca: teal si lo hace el sistema solo, navy si
  # lo hace alguien, punteado gris si todavía no existe.
  def dibujar_paso(pdf, paso, x, y, ancho, alto)
    return caja_pendiente(pdf, x, y, ancho, titulo: paso[:titulo], quien: etiqueta_de(paso), alto: alto) unless paso[:existe]

    caja(pdf, x, y, ancho, titulo: paso[:titulo], quien: etiqueta_de(paso), alto: alto,
         color: paso[:actor] == :sistema ? TEAL : NAVY)
  end

  # Cómo se escribe un estado cuando lo va a leer el cliente. `pre_alerta_estado`
  # lleva el sufijo solo para no chocar con la asociación `pre_alerta` en Ruby;
  # impreso tal cual en un documento que lee Yusef, es ruido interno.
  ESTADO_LEGIBLE = { "pre_alerta_estado" => "pre-alerta" }.freeze

  # Lo que va chiquito adentro de la caja: quién, y el estado si tiene.
  def etiqueta_de(paso)
    return paso[:quien] if paso[:estado].blank?
    "#{paso[:quien]}  ·  #{ESTADO_LEGIBLE.fetch(paso[:estado], paso[:estado])}"
  end

  MESES = %w[enero febrero marzo abril mayo junio julio agosto
             septiembre octubre noviembre diciembre].freeze

  def fecha_larga
    hoy = Date.current
    "#{hoy.day} de #{MESES[hoy.month - 1]} de #{hoy.year}"
  end
end
