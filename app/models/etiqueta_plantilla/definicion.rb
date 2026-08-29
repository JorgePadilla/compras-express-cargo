# El value object que envuelve el jsonb de la plantilla — y la fuente única
# del **default de fábrica**, que es la etiqueta exacta de hoy (los `--t1..--t7`
# del layout, mapeados campo por campo).
#
# La regla madre, calcada de EtiquetaAjustes: **un valor basura cae al default,
# nunca a la impresora.** Cada accessor clampa por clave — basura en un campo
# no tumba el resto; un JSON irreconocible (o de otra `version`) rinde el
# default entero.
class EtiquetaPlantilla < ApplicationRecord
  class Definicion
    # Los rangos son la red: la etiqueta mide ~57mm y "LOS TRACKING DEBEN
    # CABER COMPLETOS" es regla escrita de Yusef.
    ESCALA_RANGO = (70..130)
    PT_RANGO     = (4.0..40.0)
    ANCHO_RANGO  = (1.5..4.0)
    ALTO_RANGO   = (1.0..3.0)
    TEXTO_MAX    = 20
    VERSION      = 1
    # C20-02: cómo se acomoda el código de barras en su renglón. «Justificado»
    # —estirado a todo el ancho disponible— es el default y la única que no se
    # puede cortar: el SVG de Barby trae ancho fijo en píxeles, así que con las
    # otras tres el margen le puede comer la última barra y la etiqueta sale
    # ilegible sin que se note. Yusef eligió justificado sabiendo el costo:
    # *"se hace un poquito más pequeño, pero la pistola lo va a leer"*.
    ALINEACIONES = %w[justificado izquierda centro derecha].freeze

    # Qué es cada campo. `apagable: false` = identidad operativa (el barcode
    # escaneable, el número que se teclea cuando viene rayada, el tracking que
    # se compara contra la caja, y el tipo de envío que es la bandera —RET
    # incluido—): el server los fuerza visibles aunque el payload diga otra
    # cosa. `texto:` es el rótulo fijo editable; `pt_rotulo:` el tamaño del
    # rótulo cuando va aparte del dato.
    CAMPOS = {
      "barcode"             => { nombre: "Código de barras",     apagable: false, pt: false, alineacion: true },
      "numero_recepcion"    => { nombre: "Número de recepción",  apagable: false },
      "tracking"            => { nombre: "Tracking",             apagable: false },
      "tracking_secundario" => { nombre: "Tracking secundario",  apagable: true },
      "cliente_nombre"      => { nombre: "Nombre del cliente",   apagable: true },
      "tercero"             => { nombre: "Tercero",              apagable: true, texto: true },
      "fecha"               => { nombre: "Fecha y hora",         apagable: true },
      "driver"              => { nombre: "Driver",               apagable: true, texto: true },
      "reg"                 => { nombre: "Registró (iniciales)", apagable: true, texto: true, pt_rotulo: true },
      "cliente_codigo"      => { nombre: "Código del cliente",   apagable: true },
      "fraccion"            => { nombre: "Caja n/N",             apagable: true },
      "sucursal"            => { nombre: "Sucursal donde retira", apagable: true, texto: true, pt_rotulo: true },
      "ubicacion"           => { nombre: "Ciudad del cliente",   apagable: true },
      "proveedor"           => { nombre: "Proveedor (origen)",   apagable: true },
      "tipo_envio"          => { nombre: "Tipo de envío",        apagable: false },
      # C20-08: solo sale en entrega personal y recolectas. Yusef: *"es la
      # misma etiqueta, idénticas, no cambia, pero en la entrega personal y
      # recolectas va si va bien pagada o no viene pagada"*.
      "pago"                => { nombre: "Pagado / No pagado (entrega personal)", apagable: true }
    }.freeze

    # La etiqueta de hoy, 1:1. Los `pt` vienen de los tiers --t1..--t7 que
    # definió Yusef ("hay unas con letra más grande y negrita porque es lo más
    # importante… y las pequeñas para información adicional"): tipo_envio 19
    # (t1, lo más grande), nº recepción 11 (t2), código/fracción 10.5 (t3),
    # nombre/sucursal 9.5 (t4), trackings 7 (t5), fecha/reg/proveedor 6.5
    # (t6), tercero/driver/ubicación/rótulos 6 (t7). `sucursal` y `reg`
    # absorben sus rótulos («RETIRA EN», «Reg:») con su propio pt_rotulo.
    DEFAULT = {
      "version"    => VERSION,
      "dim"        => { "ancho_in" => 2.25, "alto_in" => 1.25 },
      "escala_pct" => 100,
      "filas"      => [
        { "id" => "f-barcode",   "campos" => [ "barcode" ] },
        { "id" => "f-recepcion", "campos" => [ "numero_recepcion" ] },
        { "id" => "f-tracking",  "campos" => [ "tracking" ] },
        { "id" => "f-tracking2", "campos" => [ "tracking_secundario" ] },
        { "id" => "f-cliente",   "campos" => [ "cliente_nombre", "tercero" ] },
        # C20-08: el pago viaja en el renglón del registro y NO en uno propio.
        # La etiqueta está al filo: medido en Chrome, una fila más la desborda
        # 13px. Acá cuesta ancho —que sobra— y no alto.
        { "id" => "f-registro",  "campos" => [ "pago", "fecha", "driver", "reg" ] },
        { "id" => "bloque-inferior", "tipo" => "dos_columnas",
          "izquierda" => [ [ "cliente_codigo", "fraccion" ], [ "sucursal" ] ],
          "derecha"   => [ [ "ubicacion" ], [ "proveedor", "tipo_envio" ] ] }
      ],
      "campos" => {
        "barcode"             => { "visible" => true, "alineacion" => "justificado" },
        "numero_recepcion"    => { "visible" => true, "pt" => 11.0 },
        "tracking"            => { "visible" => true, "pt" => 7.0 },
        "tracking_secundario" => { "visible" => true, "pt" => 7.0 },
        "cliente_nombre"      => { "visible" => true, "pt" => 9.5 },
        "tercero"             => { "visible" => true, "pt" => 6.0, "texto" => "3ro:" },
        "fecha"               => { "visible" => true, "pt" => 6.5 },
        "driver"              => { "visible" => true, "pt" => 6.0, "texto" => "Drv:" },
        "reg"                 => { "visible" => true, "pt" => 6.5, "pt_rotulo" => 6.0, "texto" => "Reg:" },
        "cliente_codigo"      => { "visible" => true, "pt" => 10.5 },
        "fraccion"            => { "visible" => true, "pt" => 10.5 },
        "sucursal"            => { "visible" => true, "pt" => 9.5, "pt_rotulo" => 6.0, "texto" => "RETIRA EN" },
        "ubicacion"           => { "visible" => true, "pt" => 6.0 },
        "proveedor"           => { "visible" => true, "pt" => 6.5 },
        "tipo_envio"          => { "visible" => true, "pt" => 19.0 },
        "pago"                => { "visible" => true, "pt" => 6.5 }
      }
    }.freeze

    def initialize(hash)
      @def = hash.is_a?(Hash) && hash["version"] == VERSION ? hash : DEFAULT
    end

    def ancho_in = num_en_rango(dim["ancho_in"], ANCHO_RANGO, DEFAULT["dim"]["ancho_in"])
    def alto_in  = num_en_rango(dim["alto_in"],  ALTO_RANGO,  DEFAULT["dim"]["alto_in"])

    def escala_pct
      v = Integer(@def["escala_pct"], exception: false)
      v && ESCALA_RANGO.cover?(v) ? v : DEFAULT["escala_pct"]
    end

    def pt(campo)
      num_en_rango(campo_def(campo)["pt"], PT_RANGO, campo_default(campo)["pt"])
    end

    def pt_rotulo(campo)
      num_en_rango(campo_def(campo)["pt_rotulo"], PT_RANGO, campo_default(campo)["pt_rotulo"])
    end

    # El tamaño que de verdad imprime: pt × escala, redondeado.
    def fs(campo)        = ((pt(campo) || 0) * escala_pct / 100.0).round(2)
    def fs_rotulo(campo) = ((pt_rotulo(campo) || 0) * escala_pct / 100.0).round(2)

    def visible?(campo)
      return true unless CAMPOS.fetch(campo.to_s)[:apagable]

      campo_def(campo)["visible"] != false
    end

    def texto(campo)
      v = campo_def(campo)["texto"].to_s.strip
      v.present? && v.length <= TEXTO_MAX ? v : campo_default(campo)["texto"]
    end

    # Cualquier cosa que no sea una de las cuatro cae a la de fábrica, que es
    # la que no se corta: un valor raro no puede terminar en una etiqueta que
    # no se escanea.
    def alineacion(campo)
      v = campo_def(campo)["alineacion"].to_s
      ALINEACIONES.include?(v) ? v : campo_default(campo)["alineacion"]
    end

    # El hash limpio que se persiste: todo pasado por los clamps, con la
    # identidad forzada visible y la version puesta. Lo que el editor mande de
    # más se cae; lo que falte queda en su default.
    def normalizada
      {
        "version"    => VERSION,
        "dim"        => { "ancho_in" => ancho_in, "alto_in" => alto_in },
        "escala_pct" => escala_pct,
        "filas"      => filas,
        "campos"     => CAMPOS.keys.index_with do |campo|
          d = { "visible" => visible?(campo) }
          d["pt"]        = pt(campo)        if pt(campo)
          d["pt_rotulo"] = pt_rotulo(campo) if pt_rotulo(campo)
          d["texto"]     = texto(campo)     if texto(campo)
          d["alineacion"] = alineacion(campo) if CAMPOS[campo][:alineacion]
          d
        end
      }
    end

    # Las filas rigen el orden. Una estructura irreconocible cae a las de
    # fábrica enteras: media plantilla ordenada no existe.
    #
    # C20-08: pero lo que falta o sobra se **reconcilia** en vez de tirar todo.
    # Antes se exigía cobertura exacta, y eso convertía cada campo nuevo en un
    # reseteo silencioso del orden que el operario había armado — justo lo que
    # habría pasado hoy al agregar «pago». Un campo que ya no existe se
    # descarta; uno nuevo entra en la fila donde lo pone la de fábrica.
    def filas
      dadas = @def["filas"]
      return DEFAULT["filas"] unless estructura_de_filas_ok?(dadas)

      reconciliadas = descartar_desconocidos(dadas)
      agregar_faltantes(reconciliadas)
    end

    private

    def dim
      @def["dim"].is_a?(Hash) ? @def["dim"] : {}
    end

    def campo_def(campo)
      campos = @def["campos"]
      v = campos.is_a?(Hash) ? campos[campo.to_s] : nil
      v.is_a?(Hash) ? v : {}
    end

    def campo_default(campo)
      DEFAULT["campos"].fetch(campo.to_s)
    end

    def num_en_rango(crudo, rango, default)
      return default if crudo.nil? && default.nil?

      v = Float(crudo, exception: false)
      v && rango.cover?(v) ? v : default
    end

    # Solo la forma: que sean filas y que ninguna esté rota por dentro.
    def estructura_de_filas_ok?(filas)
      return false unless filas.is_a?(Array)

      !filas.flat_map { |f| campos_de_fila(f) }.include?(nil)
    end

    # Fuera lo que no conocemos, y sin repetidos: la primera aparición gana.
    def descartar_desconocidos(filas)
      vistos = []
      limpiar = lambda do |lista|
        lista.select { |c| CAMPOS.key?(c) && !vistos.include?(c) && vistos.push(c) }
      end

      filas.map do |fila|
        if fila["tipo"] == "dos_columnas"
          fila.merge(
            "izquierda" => fila["izquierda"].map { |sub| limpiar.call(sub) },
            "derecha"   => fila["derecha"].map { |sub| limpiar.call(sub) }
          )
        else
          fila.merge("campos" => limpiar.call(fila["campos"]))
        end
      end
    end

    # Los que la plantilla guardada no menciona entran donde los pone la de
    # fábrica: si su fila original sigue existiendo, ahí; si no, en una propia
    # al final.
    def agregar_faltantes(filas)
      presentes = filas.flat_map { |f| campos_de_fila(f) }
      faltantes = CAMPOS.keys - presentes
      return filas if faltantes.empty?

      DEFAULT["filas"].each_with_object(filas.dup) do |fila_default, acc|
        pendientes = campos_de_fila(fila_default) & faltantes
        next if pendientes.empty?

        destino = acc.find { |f| f["id"] == fila_default["id"] && f["tipo"] != "dos_columnas" }
        if destino
          destino["campos"] = destino["campos"] + pendientes
        else
          acc << { "id" => fila_default["id"], "campos" => pendientes }
        end
      end
    end

    # Los campos que nombra una fila — nil marca estructura rota.
    def campos_de_fila(fila)
      return [ nil ] unless fila.is_a?(Hash)

      if fila["tipo"] == "dos_columnas"
        izq = fila["izquierda"]
        der = fila["derecha"]
        return [ nil ] unless izq.is_a?(Array) && der.is_a?(Array)

        (izq + der).flat_map { |sub| sub.is_a?(Array) ? sub : [ nil ] }
      else
        fila["campos"].is_a?(Array) ? fila["campos"] : [ nil ]
      end
    end
  end
end
