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
  def etiqueta_barcode_svg(texto, height: 34, xdim: 1)
    valor = texto.to_s.strip
    return nil if valor.blank?

    barcode = Barby::Code128B.new(valor)
    svg = Barby::SvgOutputter.new(barcode)
      .to_svg(height: height, margin: 0, xdim: xdim)
      .sub(/<\?xml[^>]*\?>\s*/, "") # inline: sin prolog XML
    svg.html_safe
  rescue StandardError => e
    # Un carácter fuera de Code128B no puede tumbar la impresión de la
    # etiqueta — se degrada a solo texto.
    Rails.logger.warn "[etiqueta] no se pudo generar el codigo de barras para #{valor.inspect}: #{e.message}"
    nil
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
  # C16-07 · El retenido en Miami imprime **RTE** en ese mismo lugar. Yusef,
  # 2026-08-25, con las tres etiquetas de un paquete retenido en la mano: *"y
  # sigue saliendo el CER aquí. Mirá, sería así: retenido"*; y la abreviatura,
  # después: *"el de retener me dijiste RT, me va. RT, RT, RT"*. Jorge lo fijó:
  # en lugar del servicio, RTE. Es el texto más grande de la etiqueta porque es
  # con lo que separan la carga antes de empacar — y una caja retenida no se
  # empaca. El servicio vuelve a imprimirse cuando se libera la retención
  # (`reimprimir_etiquetas`). Es la bandera `retener_miami`, no el estado
  # `retenido` (que es otra cosa: un paso del pipeline en Honduras).
  def etiqueta_tipo_envio(paquete)
    return "RTE" if paquete.retener_miami?

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
end
