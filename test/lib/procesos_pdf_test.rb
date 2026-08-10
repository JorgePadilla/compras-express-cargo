require "test_helper"
require "prawn"
require "prawn/table"
require Rails.root.join("lib/procesos_pdf")

# PR: los diagramas de proceso que se le mandan a Yusef.
#
# Un diagrama de proceso envejece peor que cualquier documento: la pantalla se
# mueve, el estado se renombra, y el dibujo sigue diciendo lo de antes. Nadie se
# entera hasta que el cliente pregunta por una pantalla que ya no existe.
#
# Por eso los flujos están escritos como **datos** y no como dibujo suelto: así
# se pueden confrontar contra el sistema de verdad. Estos tests son eso.
class ProcesosPdfTest < ActiveSupport::TestCase
  setup { @doc = ProcesosPdf.new }

  # ── Que el diagrama no mienta ───────────────────────────────────────────

  test "cada pantalla que el diagrama nombra existe de verdad" do
    # EL test de este archivo. Si alguien renombra una ruta, el diagrama deja de
    # ser cierto y esto lo agarra antes de que se imprima.
    helpers = Rails.application.routes.url_helpers
    inventadas = @doc.todos_los_pasos.filter_map do |p|
      next if p[:ruta].blank?
      "#{p[:titulo]} → #{p[:ruta]}" unless helpers.respond_to?(p[:ruta])
    end

    assert_empty inventadas, "el diagrama apunta a pantallas que no existen:\n#{inventadas.join("\n")}"
  end

  test "cada estado que el diagrama nombra existe en el sistema" do
    inventados = @doc.todos_los_pasos.filter_map do |p|
      next if p[:estado].blank?
      "#{p[:titulo]} → #{p[:estado]}" unless Paquete.estados.key?(p[:estado])
    end

    assert_empty inventados, "el diagrama nombra estados que no existen:\n#{inventados.join("\n")}"
  end

  test "los estados que se reescriben para el cliente siguen existiendo" do
    # Si el enum renombra `pre_alerta_estado`, el diccionario deja de aplicar en
    # silencio y el PDF vuelve a imprimir el nombre interno.
    inventados = ProcesosPdf::ESTADO_LEGIBLE.keys.reject { |e| Paquete.estados.key?(e) }

    assert_empty inventados
  end

  test "no queda ningun nombre interno impreso en las cajas" do
    # `pre_alerta_estado` se lee como error de tipeo. Cualquier estado con
    # sufijo `_estado` hay que reescribirlo antes de mandarlo.
    crudos = @doc.todos_los_pasos.filter_map do |p|
      next if p[:estado].blank?
      p[:estado] if ProcesosPdf::ESTADO_LEGIBLE.fetch(p[:estado], p[:estado]).end_with?("_estado")
    end

    assert_empty crudos
  end

  test "todo paso dice quien lo hace" do
    # En un diagrama de proceso la pregunta que más se hace es "¿y esto quién lo
    # hace?". Un paso sin dueño no sirve.
    mudos = @doc.todos_los_pasos.reject { |p| p[:quien].present? }

    assert_empty mudos.map { |p| p[:titulo] }
  end

  test "todo paso dice si lo hace una persona, el sistema o el mundo" do
    validos = %i[persona sistema fisico]
    raros = @doc.todos_los_pasos.reject { |p| validos.include?(p[:actor]) }

    assert_empty raros.map { |p| p[:titulo] }
  end

  # ── Los huecos ──────────────────────────────────────────────────────────

  test "los cuatro huecos salen marcados" do
    assert_equal [ "Empacar", "Aduana", "Bodega en Honduras", "Firma y foto" ],
                 @doc.huecos.map { |h| h[:titulo] }
  end

  test "empacar esta marcado como que no existe, y es verdad" do
    # `empacado` está en el enum y en ESTADOS_ORDEN, pero NINGÚN controller lo
    # asigna: `EtiquetarController` lo dice —"queda reservado para el módulo de
    # empaque, que todavía no existe"— y el manifiesto salta de `recibido_miami`
    # a `enviado_honduras`. Si algún día alguien construye la pantalla, este
    # test recuerda actualizar el diagrama.
    empacar = @doc.todos_los_pasos.find { |p| p[:estado] == "empacado" }

    assert_not empacar[:existe]
    assert_empty quien_asigna("empacado"),
                 "ya hay código que asigna `empacado`: el diagrama quedó viejo"
  end

  test "un hueco no tiene ruta, porque no hay pantalla" do
    con_ruta = @doc.huecos.select { |h| h[:ruta].present? }

    assert_empty con_ruta.map { |h| h[:titulo] },
                 "un paso marcado como pendiente no puede apuntar a una pantalla"
  end

  # ── Los flujos alternativos ─────────────────────────────────────────────

  test "cada flujo alternativo dice cuando se usa y donde se pega" do
    # Un flujo suelto, sin decir de dónde sale ni a dónde vuelve, no se entiende.
    incompletos = ProcesosPdf::ALTERNATIVOS.reject do |f|
      f[:cuando].present? && f[:engancha].present? && f[:pasos].any?
    end

    assert_empty incompletos.map { |f| f[:nombre] }
  end

  test "estan los ocho desvios" do
    assert_equal 8, ProcesosPdf::ALTERNATIVOS.size
  end

  test "los flujos que se bifurcan se dibujan como abanico" do
    # Retorno/desecho/anulación son EXCLUYENTES entre sí, igual que débito y
    # crédito. Dibujados en cadena —que es la forma por defecto— el diagrama
    # decía que un paquete devuelto después se destruye y después se anula.
    bifurcados = ProcesosPdf::ALTERNATIVOS.select { |f| f[:forma] == :abanico }.map { |f| f[:nombre] }

    assert_equal [ "Retorno, desecho y anulación", "Notas de débito y de crédito" ], bifurcados
  end

  test "no hay formas de dibujo inventadas" do
    # Una `forma:` mal escrita no revienta: cae en el default y vuelve a dibujar
    # la cadena que este PR arregló. Se rompe acá o no se rompe en ningún lado.
    raras = ProcesosPdf::ALTERNATIVOS.reject { |f| [ nil, :abanico ].include?(f[:forma]) }

    assert_empty raras.map { |f| f[:nombre] }
  end

  test "un abanico tiene tronco y al menos dos ramas" do
    cortos = ProcesosPdf::ALTERNATIVOS.select { |f| f[:forma] == :abanico && f[:pasos].size < 3 }

    assert_empty cortos.map { |f| f[:nombre] }
  end

  test "el ejemplo de tracking EP esta armado como el sistema lo arma" do
    # `MIA` es el `codigo` de la sucursal de Miami; el tracking usa `codigo_ep`,
    # que es otra cosa (`SMI`). Y la sucursal que entra no es Miami sino la
    # **de retiro** — `heredar_sucursal_de_retiro` en el controller. El ejemplo
    # decía `EP-2026-MIA-UBR-000042`, que no lo puede generar ningún paquete.
    anio, suc, prov, num = ProcesosPdf::EJEMPLO_TRACKING_EP.delete_prefix("EP-").split("-")

    assert_match(/\A\d{4}\z/, anio)
    assert_match(/\A\d{6}\z/, num)
    assert_includes Sucursal.where.not(codigo_ep: nil).pluck(:codigo_ep), suc,
                    "`#{suc}` no es el codigo_ep de ninguna sucursal"
    assert_includes Proveedor.where(tipo: "entrega_personal").pluck(:codigo), prov,
                    "`#{prov}` no es el código de ningún proveedor de entrega personal"
  end

  test "el ejemplo de tracking EP sale de una sucursal de retiro" do
    # Miami no es sucursal de retiro: el cliente no va a recoger a Miami. Si el
    # ejemplo usa el codigo_ep de Miami, el diagrama enseña un tracking que el
    # sistema no genera.
    suc = ProcesosPdf::EJEMPLO_TRACKING_EP.split("-")[2]

    assert_equal "honduras", Sucursal.find_by(codigo_ep: suc).ubicacion
  end

  # ── Las preguntas ───────────────────────────────────────────────────────

  test "las preguntas siguen la numeracion del PDF de servicios" do
    # Ese llegó hasta RP-29. Si dos documentos usan el mismo número, las
    # respuestas de Yusef se pisan.
    numeros = ProcesosPdf::PREGUNTAS.map { |q| q[:numero] }

    assert_equal %w[RP-30 RP-31 RP-32 RP-33 RP-34], numeros
  end

  test "cada pregunta ofrece al menos dos caminos" do
    pobres = ProcesosPdf::PREGUNTAS.reject { |q| q[:opciones].size >= 2 }

    assert_empty pobres.map { |q| q[:numero] }
  end

  test "hay al menos una pregunta por cada hueco" do
    # Si se marca un hueco en el dibujo y no se pregunta nada, el documento
    # señala un problema sin pedir una decisión. Agregar un hueco obliga a
    # agregar la pregunta.
    assert_operator ProcesosPdf::PREGUNTAS.size, :>=, @doc.huecos.size
  end

  # ── Que salga ───────────────────────────────────────────────────────────

  test "el documento se genera" do
    salida = @doc.render

    assert salida.start_with?("%PDF-")
    assert_operator salida.bytesize, :>, 10_000
  end

  test "no usa italica, que no esta registrada" do
    # Solo están cargadas normal y bold: `<i>` levanta
    # `Prawn::Errors::UnknownFont` a mitad del render. Pasó una vez.
    textos = ProcesosPdf::PREGUNTAS.map { |q| q[:cuerpo] } +
             ProcesosPdf::ALTERNATIVOS.flat_map { |f| [ f[:cuando], f[:engancha], *f[:notas] ] }

    assert_empty textos.select { |t| t.include?("<i>") }
  end

  private

  # Dónde el código **escribe** un estado. Solo escrituras: `where(estado: ...)`
  # y los diccionarios de etiquetas nombran estados todo el tiempo sin
  # asignarlos, y contarlos haría que el test no signifique nada.
  def quien_asigna(estado)
    escritura = /estado\s*[:=]\s*["':]#{estado}\b|\.#{estado}!/

    Dir.glob(Rails.root.join("app/**/*.rb")).filter_map do |archivo|
      linea = File.readlines(archivo).index { |l| l.match?(escritura) }
      "#{Pathname(archivo).relative_path_from(Rails.root)}:#{linea + 1}" if linea
    end
  end
end
