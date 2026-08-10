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
  CAMINO_MIAMI = [
    { titulo: "Pre-alerta", quien: "el cliente, en su portal",
      actor: :persona, ruta: "new_cuenta_pre_alerta_path", existe: true },
    { titulo: "Nace el paquete", quien: "el sistema, solo",
      actor: :sistema, estado: "pre_alerta_estado", existe: true },
    { titulo: "Llega el camión a Miami", quien: "el courier",
      actor: :fisico, existe: true },
    { titulo: "Etiquetar", quien: "digitador de Miami",
      actor: :persona, ruta: "etiquetar_path", estado: "recibido_miami", existe: true },
    { titulo: "Empacar", quien: "no hay pantalla todavía",
      actor: :persona, estado: "empacado", existe: false },
    { titulo: "Manifiesto", quien: "supervisor de Miami",
      actor: :persona, ruta: "manifiestos_path", estado: "enviado_honduras", existe: true }
  ].freeze

  CAMINO_HONDURAS = [
    { titulo: "Aduana", quien: "hoy se cambia el estado a mano",
      actor: :persona, estado: "en_aduana", existe: false },
    { titulo: "Bodega en Honduras", quien: "hoy se cambia el estado a mano",
      actor: :persona, estado: "disponible_entrega", existe: false },
    { titulo: "Pre-factura", quien: "cajero",
      actor: :persona, ruta: "pre_facturas_path", estado: "pre_facturado", existe: true },
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

  # Las preguntas que salen de los huecos. Siguen la numeración del PDF de
  # servicios, que llegó hasta RP-29.
  PREGUNTAS = [
    { numero: "RP-30", titulo: "Empacar: ¿lo construimos?",
      cuerpo: "El paso de <b>empacar</b> está en el sistema como estado, pero no hay pantalla que lo haga. " \
              "Vos mismo lo dejaste para después: «no sé si lo cargamos ahorita». " \
              "Hoy el paquete pasa de etiquetado directo al manifiesto.",
      opciones: [ "Sí, constrúyanlo — quiero saber qué caja salió y cuándo",
                  "Todavía no, seguimos así",
                  "Solo el escaneo al empacar, sin el módulo completo" ] },

    { numero: "RP-31", titulo: "Aduana y bodega: hoy se cambia el estado a mano",
      cuerpo: "Entre que sale el manifiesto y que el paquete queda listo para facturar, <b>no hay pantalla</b>. " \
              "Alguien entra a la ficha del paquete y le cambia el estado. Es el hueco más grande que tiene el sistema.",
      opciones: [ "Necesitamos una pantalla para recibir el manifiesto completo de un golpe",
                  "Está bien cambiarlo paquete por paquete",
                  "Que se marque solo cuando llega el manifiesto" ] },

    { numero: "RP-32", titulo: "¿Hace falta firma o foto al entregar?",
      cuerpo: "Hoy la entrega guarda el nombre y la identidad de quien recibe, pero <b>no hay firma ni foto</b>. " \
              "Nadie lo ha pedido — preguntamos antes de asumir que no hace falta.",
      opciones: [ "Sí, firma en la pantalla del celular",
                  "Sí, una foto del paquete entregado",
                  "Con el nombre y la identidad alcanza" ] },

    { numero: "RP-33", titulo: "¿Las tareas pendientes deberían frenar el manifiesto?",
      cuerpo: "Si un paquete tiene una tarea sin terminar, el sistema <b>no lo deja pasar a pre-factura</b>. " \
              "Pero al manifiesto <b>sí lo deja salir</b>. La misma regla vale en un paso y en el otro no.",
      opciones: [ "Que tampoco lo deje salir en el manifiesto",
                  "Está bien así: el manifiesto no espera a nadie",
                  "Que avise pero deje seguir" ] },

    { numero: "RP-34", titulo: "Con pago parcial, ¿se puede entregar?",
      cuerpo: "Hoy el paquete queda listo para entregar <b>solo cuando la factura se paga completa</b>. " \
              "Con un abono parcial no aparece en la pantalla de entregas.",
      opciones: [ "Está bien: sin pago completo no sale",
                  "Que se pueda entregar con un abono",
                  "Que se pueda, pero con autorización de un supervisor" ] }
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
      p_(pdf, "Al final hay cinco preguntas. Marcá la casilla con una X y mandá la foto.", size: 9.5)
    end
    pdf.move_down 24

    h2(pdf, "Cómo leer los dibujos")
    pdf.move_down 6
    leyenda(pdf, pdf.cursor)

    pdf.move_down 20
    tabla(pdf, [ "Símbolo", "Qué significa" ], [
      [ "Caja de borde entero", "Un paso que ya existe en el sistema" ],
      [ "Caja de borde punteado", "Un paso del proceso que <b>todavía no tiene pantalla</b>" ],
      [ "Rombo", "Una decisión: el camino se parte en dos" ],
      [ "Texto chiquito adentro", "Quién lo hace — una persona, o el sistema solo" ]
    ], anchos: [ 160, 362 ])
  end

  def pagina_miami(pdf)
    h1(pdf, "En Miami")
    p_(pdf, "Desde que el cliente avisa que viene un paquete hasta que sale el manifiesto.")

    y = pdf.cursor - 10
    cajas = columna(pdf, CAMINO_MIAMI, x: 60, y: y)

    nota(pdf, 290, cajas[3][:y] - 4,
         "Si el tracking coincide con una pre-alerta, el sistema los amarra solo y le avisa al cliente por correo.", ancho: 180)
    nota(pdf, 290, cajas[4][:y] - 4,
         "Está diseñado (Fase 12) pero no construido. Hoy el paquete pasa de etiquetado directo al manifiesto.", ancho: 180)

    pdf.move_cursor_to cajas.last[:y] - cajas.last[:alto] - 30
    h2(pdf, "Una cosa que conviene saber")
    p_(pdf, "Cuando sale el manifiesto, el sistema mueve <b>todos los paquetes de un golpe</b>. " \
            "Y no revisa si alguno tiene tareas pendientes — a diferencia de la pre-factura, que sí las revisa. " \
            "Es la pregunta <b>RP-33</b> del final.")
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

  def pagina_preguntas(pdf)
    h1(pdf, "Lo que necesitamos que decidas")
    p_(pdf, "Cinco preguntas que salen de los dibujos de atrás. Marcá con una X.")

    PREGUNTAS.each do |q|
      pregunta(pdf, q[:numero], q[:titulo])
      p_(pdf, q[:cuerpo])
      q[:opciones].each { |o| opcion(pdf, o) }
      opcion(pdf, "Otro:")
      linea(pdf)
    end
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
