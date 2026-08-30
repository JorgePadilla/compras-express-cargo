require "barby"
require "barby/barcode/code_128"
require "barby/outputter/svg_outputter"

# PR-10.d: la etiqueta física que se pega a la caja.
#
# Yusef (2026-08-02) mandó la etiqueta del sistema legacy con cada campo
# anotado, y aclaró que ETIQUETAR imprime en **Dymo 2.25 × 1.25 pulgadas**,
# una por paquete. A ese tamaño no caben los 11 campos legibles, así que hay
# jerarquía: lo que el operario tiene que leer de lejos en la estantería va
# grande, el resto va de apoyo.
module EtiquetaHelper
  # Code 128 del número de recepción — "código de barra de número de
  # recepción". No existía nada escaneable en el sistema: el tracking había
  # que teclearlo a mano.
  #
  # SVG en vez de PNG a propósito: es vectorial, así que imprime nítido tanto
  # en la Dymo de 203 dpi como en cualquier otra, y no necesita una gema de
  # imágenes.
  # C20-02: `estirar` es lo que hace que la pistola pueda leerlo siempre.
  #
  # Barby emite el SVG con **ancho fijo en píxeles** (el que le toque al
  # código: 211px para un número de recepción con sufijo). La etiqueta mide
  # 2.25in y los márgenes le comen ancho, así que cuando el código no entra,
  # `overflow:hidden` le corta la última barra **en silencio** — la etiqueta se
  # ve bien y no se escanea. Yusef, probándolo en vivo: *"sí, le cortó la
  # última, la derecha… le faltan rayitas"*, y el diagnóstico es suyo: *"la
  # idea de ese margen es que lo corre para la derecha; el problema es que como
  # ya no hay espacio, donde lo corre para la derecha se corta"*.
  #
  # Estirado, el ancho lo pone el contenedor y el dibujo se acomoda:
  #
  #   > "Si lo justificás, lo que va a pasar es que se hace un poquito más
  #   >  pequeño el código de barra, **pero la pistola lo va a leer**. Eso es
  #   >  lo que hay que hacer."
  #
  # Y es cierto: Code 128 se lee por la **proporción** entre barras y espacios,
  # no por su ancho absoluto, así que escalar parejo no lo rompe.
  #
  # El SVG de Barby ya trae `viewBox` y `preserveAspectRatio="none"`, o sea que
  # alcanza con cambiarle el ancho y el alto del tag de apertura — nada de
  # reescribir el dibujo. `sub` y no `gsub`: adentro van decenas de `<rect>`
  # con su propio width/height, y ésos no se tocan. Si algún día Barby cambia
  # de forma y el patrón no engancha, sale el SVG tal cual: se degrada al
  # comportamiento de antes, nunca a una etiqueta sin código.
  def etiqueta_barcode_svg(texto, height: 34, xdim: 1, estirar: true)
    valor = texto.to_s.strip
    return nil if valor.blank?

    barcode = Barby::Code128B.new(valor)
    svg = Barby::SvgOutputter.new(barcode)
      .to_svg(height: height, margin: 0, xdim: xdim)
      .sub(/<\?xml[^>]*\?>\s*/, "") # inline: sin prolog XML
    if estirar
      svg = svg.sub(/\A\s*<svg\b[^>]*>/) do |tag|
        tag.sub(/\bwidth="[^"]*"/, 'width="100%"').sub(/\bheight="[^"]*"/, 'height="100%"')
      end
    end
    svg.html_safe
  rescue StandardError => e
    # Un carácter fuera de Code128B no puede tumbar la impresión de la
    # etiqueta — se degrada a solo texto.
    Rails.logger.warn "[etiqueta] no se pudo generar el codigo de barras para #{valor.inspect}: #{e.message}"
    nil
  end

  # C21-05 / RP-54 · El QR del bulto.
  #
  # `A7-03` dejó la puerta abierta —*"un código QR o lo que vos querás"*— y
  # `RP-54` la preguntó, avisando que el repo solo generaba Code128 y que QR
  # pedía gema nueva. Yusef eligió el 2026-08-30: *"código QR, habría que
  # instalar la gema necesaria"*, o sea aceptando el costo.
  #
  # Va **solo en la etiqueta del bulto**. El warehouse del paquete sigue en
  # Code128 (`etiqueta_barcode_svg`), que es lo que leen las pistolas de hoy;
  # cambiar los dos de un saque dejaría a Miami sin poder escanear nada.
  #
  # `use_path: true` + `viewbox: true` para que el SVG escale con su caja en vez
  # de traer un ancho fijo en píxeles, que es lo que rompe al imprimir a 4×6.
  #
  # 1.7in de lado: la 4×6 tenía espacio de sobra donde antes iba el Code128 a
  # todo el ancho, y un QR grande es un QR que la pistola agarra de lejos y
  # torcido. Va alineado a la izquierda como todo lo demás de la etiqueta.
  # Y el mismo degradado que el barcode: si algo revienta sale sin código, nunca
  # una excepción en medio de una impresión.
  def etiqueta_qr_svg(texto, tamano: "1.7in")
    valor = texto.to_s.strip
    return nil if valor.blank?

    svg = RQRCode::QRCode.new(valor)
      .as_svg(module_size: 4, use_path: true, viewbox: true, standalone: true)
      .sub(/<\?xml[^>]*\?>\s*/, "")

    # Con `viewbox: true` el SVG sale **sin** `width` ni `height` — se insertan,
    # no se sustituyen. Sustituirlos era un no-op silencioso: el QR salía con el
    # tamaño que le diera la caja contenedora, que en 4×6 es todo el ancho.
    svg = svg.sub(/\A\s*<svg\b/, %(<svg width="#{tamano}" height="#{tamano}"))
    svg.html_safe
  rescue StandardError => e
    Rails.logger.warn "[etiqueta] no se pudo generar el QR para #{valor.inspect}: #{e.message}"
    nil
  end

  # El renglón donde vive el código de barras.
  #
  # C20-02: justificado no necesita alinear nada —el dibujo ya ocupa todo el
  # ancho— y por eso va como bloque pelado, que es el camino que tenía la
  # etiqueta desde siempre. Las otras tres van con flex, empujando un SVG que
  # conserva su ancho natural.
  POSICION_DEL_BARCODE = { "centro" => "center", "derecha" => "flex-end" }.freeze

  def etiqueta_barcode_estilo(alineacion)
    base = "width:100%; height:.20in;"
    return base if alineacion == "justificado"

    "#{base} display:flex; justify-content:#{POSICION_DEL_BARCODE.fetch(alineacion, 'flex-start')};"
  end

  # Lo que va adentro del código de barras — y también impreso debajo, para
  # poder teclearlo cuando la etiqueta viene rayada.
  #
  # Dos reglas de Yusef, las dos del 2026-08-08:
  #
  # **1. Es el warehouse, nunca el tracking.**
  #
  #   > "El código de barra que está aquí es el warehouse, no es el tracking."
  #
  # Por eso devuelve `nil` cuando no hay número de recepción, en vez de caer al
  # tracking como hacía antes: una etiqueta sin barcode es un problema visible;
  # una con el barcode equivocado se escanea mal en San Pedro y nadie se entera.
  #
  # **2. Lleva el sufijo de caja cuando el tracking se dividió.**
  #
  #   > "Si yo escaneo esto no sé si es el paquete uno o el paquete dos."
  #   > "Aquí sería 7-1, 7-2."
  #
  # Las N cajas de un split comparten el `numero_recepcion` (el número madre),
  # y se diferencian por `numero_caja` — el índice único es compuesto. Sin el
  # sufijo las dos cajas llevan el MISMO código impreso, y al recibir en San
  # Pedro no se puede saber cuál llegó ni cuál falta. Eso es lo que rompe el
  # rebaje de inventario:
  #
  #   > "Esa etiqueta selecciona del inventario... el paquete que sí vino, y
  #   >  que falta el otro. De esa manera él rebaja."
  #
  # El sufijo va en la **recepción**, jamás en el tracking. Ese fue el error
  # del sistema viejo: "el tracking él le agregaba un 2, y al warehouse él le
  # agregaba un 2 y el 1".
  def etiqueta_codigo_barras(paquete)
    recepcion = paquete.numero_recepcion_visible
    return nil if recepcion.blank?
    return recepcion unless paquete.dividido? && paquete.numero_caja.to_i.positive?

    "#{recepcion}-#{paquete.numero_caja}"
  end

  # El número de caja, solo. **Sin el total.**
  #
  # A7-21. Esto era "1/2" y Yusef lo cortó, explicando por qué el total no se
  # puede saber cuando se imprime:
  #
  #   > "La etiqueta **solo lleva el número, no lleva el uno de dos ni de
  #   >  tres**, porque no estamos seguros cuántas estamos empacando."
  #   > "Cuando menos acordás: hey, me salieron cuatro en vez de cinco."
  #
  # Una etiqueta que dice "1/5" sobre una carga que terminó en 4 cajas es peor
  # que una que no dice nada: manda a buscar un bulto que no existe.
  #
  # 2026-08-19, Jorge sobre una etiqueta de dos cajas: *"el 1 está bien, pero
  # aquí yo mandé 2 — cuando manda más de una debe llevar el 1/2"*.
  #
  # Los dos tienen razón, sobre casos distintos, y por eso la fracción sale
  # **solo cuando el total está grabado**:
  #
  #   · Al **recibir**, la cantidad se fija antes de imprimir — el operario cargó
  #     las cajas una por una, o contestó cuántas en el modal de `PR-C7.23`. El
  #     paquete queda con `cantidad_paquetes`, y por eso el código de barras ya
  #     salía con su `-1`. Ahí el total se sabe y decirlo ayuda.
  #   · Al **empacar** —el módulo que Yusef difirió— la cantidad va apareciendo
  #     mientras se empaca. Ahí no hay `cantidad_paquetes` que valga y sale el
  #     número solo, que es exactamente el caso del que él se quejaba.
  #
  # O sea que esto respeta su razón, no su letra. Si algún día el empaque graba
  # un total provisorio, hay que volver a mirar esta línea.
  #
  # Ojo: esto NO es el sufijo del código de barras. `etiqueta_codigo_barras`
  # sigue emitiendo `RM…-2`, que es lo que permite rebajar inventario caja por
  # caja en San Pedro. Son dos cosas distintas en dos lugares distintos.
  def etiqueta_fraccion(paquete)
    numero = (paquete.numero_caja.presence || 1).to_s
    return numero unless paquete.dividido?

    "#{numero}/#{paquete.cantidad_paquetes}"
  end

  # "Departamento abreviado y ciudad o pueblo" (Yusef). El departamento
  # hondureño va abreviado a 3 letras para que quepa.
  def etiqueta_ubicacion_cliente(cliente)
    return nil if cliente.nil?

    depto = cliente.departamento.to_s.strip
    ciudad = cliente.ciudad.to_s.strip
    [ depto.presence&.first(3)&.upcase, ciudad.presence ].compact.join(" · ").presence
  end

  # La sucursal donde el cliente retira. Es el campo que provocó el
  # "¿qué es San Pedro Soda?": salía truncado y bajo un encabezado en inglés.
  def etiqueta_sucursal(paquete)
    paquete.sucursal&.nombre.presence || paquete.cliente&.ciudad.presence
  end

  # El tipo de envío va a tres letras: en el mockup de Yusef dice **EXP**, no
  # EXPRESS. No es cosmético — es el texto más grande de la etiqueta, y con
  # "EXPRESS" completo a ese cuerpo se come más de la mitad del ancho y deja la
  # sucursal truncada en "S…", que es exactamente el "¿qué es San Pedro Soda?"
  # que este rediseño vino a arreglar.
  #
  # CER, CEM, CKA y CKM ya son de tres letras; el único que se acorta es
  # EXPRESS. Si algún día entran dos servicios que arranquen igual, hay que
  # mapearlos a mano acá.
  #
  # C16-07 · El retenido en Miami imprime **RET** en ese mismo lugar. Yusef,
  # 2026-08-25, con las tres etiquetas de un paquete retenido en la mano: *"y
  # sigue saliendo el CER aquí. Mirá, sería así: retenido"*; y la abreviatura,
  # después: *"el de retener me dijiste RT, me va. RT, RT, RT"*. Jorge lo fijó:
  # en lugar del servicio, las **primeras tres letras de RETENIDO** — salió
  # como RTE en el primer intento y Yusef lo corrigió al día siguiente (C18-01:
  # *"me dijiste RTE… RET. Sí, las primeras tres letras"*). Es el texto más
  # grande de la etiqueta porque es
  # con lo que separan la carga antes de empacar — y una caja retenida no se
  # empaca. El servicio vuelve a imprimirse cuando se libera la retención
  # (`reimprimir_etiquetas`). Es la bandera `retener_miami`, no el estado
  # `retenido` (que es otra cosa: un paso del pipeline en Honduras).
  def etiqueta_tipo_envio(paquete)
    return "RET" if paquete.retener_miami?

    paquete.tipo_envio&.codigo.to_s.first(3).upcase.presence
  end

  # De dónde viene el paquete: el comercio donde se compró, con el código de 3
  # letras del catálogo de proveedores (AMZ, WMT, TAR). Yusef pidió que fuera al
  # lado del tipo de envío — "¿creés que quepa de dónde viene?" — y con tres
  # letras entra sin robarle ancho al EXP.
  #
  # Se usa el código y no el nombre porque va grande: "Amazon" o "Sams Club"
  # completos dejarían la sucursal truncada otra vez.
  def etiqueta_proveedor(paquete)
    paquete.proveedor&.codigo.presence&.upcase
  end

  # Iniciales de un nombre libre, con el mismo criterio que
  # `User#iniciales_display`: las primeras letras de las dos primeras palabras.
  #
  # Yusef sobre el driver: "solo usamos iniciales". El nombre completo se comía
  # el ancho de la fecha, que en su jerarquía está por encima.
  def etiqueta_iniciales(texto)
    partes = texto.to_s.split(/\s+/).reject(&:blank?).first(2)
    return nil if partes.empty?

    partes.map { |p| p[0].to_s.upcase }.join
  end

  # ── C19-06: la plantilla que rige la etiqueta ──

  # Memoizada por request: layout y partial comparten el view context, y
  # `etiquetas_combinadas` renderiza N etiquetas — una consulta, no N.
  # El preview del editor la pisa (`@etiqueta_plantilla = candidata`) para
  # renderizar una definición sin guardar.
  def etiqueta_plantilla
    @etiqueta_plantilla ||= EtiquetaPlantilla.vigente
  end

  # Una fila de campos: si es un solo campo, el partial trae su propio bloque;
  # si son varios, van juntos en un renglón `.r` — que solo se emite si algún
  # campo rindió algo (igual que hoy: sin secundario no hay div vacío).
  def etiqueta_fila(campos, paquete)
    piezas = campos.filter_map do |campo|
      html = etiqueta_campo(campo, paquete)
      html if html.present? && html.strip.present?
    end
    return "".html_safe if piezas.empty?
    return piezas.first if campos.size == 1

    content_tag(:div, safe_join(piezas), class: "r")
  end

  def etiqueta_campo(campo, paquete)
    return "".html_safe unless EtiquetaPlantilla::Definicion::CAMPOS.key?(campo)

    render("paquetes/etiqueta_campos/#{campo}", paquete: paquete)
  end

  # Las variables CSS de tamaño, una por campo (`--fs-tipo-envio: 19pt`),
  # ya multiplicadas por la escala. El barcode no tiene: su alto es fijo
  # (abajo de ~0.15in los escáneres fallan y no se ve en la impresión).
  def etiqueta_font_vars
    plantilla = etiqueta_plantilla
    lineas = EtiquetaPlantilla::Definicion::CAMPOS.keys.filter_map do |campo|
      fs = plantilla.fs(campo)
      next if fs.zero?

      linea = "--fs-#{campo.tr('_', '-')}: #{etiqueta_num(fs)}pt;"
      if (fsr = plantilla.fs_rotulo(campo)).positive?
        linea += "\n      --fs-#{campo.tr('_', '-')}-rotulo: #{etiqueta_num(fsr)}pt;"
      end
      linea
    end
    lineas.join("\n      ").html_safe
  end

  # 19.0 → "19", 10.5 → "10.5", 2.25 → "2.25" — como estaban escritos a mano.
  def etiqueta_num(n)
    (n % 1).zero? ? n.to_i.to_s : n.to_s
  end
end
