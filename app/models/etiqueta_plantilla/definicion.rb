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

    # Qué es cada campo. `apagable: false` = identidad operativa (el barcode
    # escaneable, el número que se teclea cuando viene rayada, el tracking que
    # se compara contra la caja, y el tipo de envío que es la bandera —RET
    # incluido—): el server los fuerza visibles aunque el payload diga otra
    # cosa. `texto:` es el rótulo fijo editable; `pt_rotulo:` el tamaño del
    # rótulo cuando va aparte del dato.
    CAMPOS = {
      "barcode"             => { nombre: "Código de barras",     apagable: false, pt: false },
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
      "tipo_envio"          => { nombre: "Tipo de envío",        apagable: false }
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
        { "id" => "f-registro",  "campos" => [ "fecha", "driver", "reg" ] },
        { "id" => "bloque-inferior", "tipo" => "dos_columnas",
          "izquierda" => [ [ "cliente_codigo", "fraccion" ], [ "sucursal" ] ],
          "derecha"   => [ [ "ubicacion" ], [ "proveedor", "tipo_envio" ] ] }
      ],
      "campos" => {
        "barcode"             => { "visible" => true },
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
        "tipo_envio"          => { "visible" => true, "pt" => 19.0 }
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
          d
        end
      }
    end

    # Las filas rigen el orden. Estructura irreconocible —o que no cubra
    # exactamente los campos conocidos, sin duplicar— cae a las filas de
    # fábrica enteras: media plantilla ordenada no existe.
    def filas
      dadas = @def["filas"]
      return DEFAULT["filas"] unless filas_validas?(dadas)

      dadas
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

    def filas_validas?(filas)
      return false unless filas.is_a?(Array)

      vistos = filas.flat_map { |f| campos_de_fila(f) }
      return false if vistos.include?(nil)

      vistos.sort == CAMPOS.keys.sort
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
