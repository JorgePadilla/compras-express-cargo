require "test_helper"

# PR: que no vuelva a haber un sonido cableado en la vista que nadie dispara.
#
# `etiquetar:modalAbierto->audio#notify` estuvo puesto en la vista desde
# `PR-C6.16` y **ningún controller disparaba ese evento**. El modal de sucursal
# de retiro y el del PIN del supervisor abrían mudos durante meses, con el
# documento marcando la fila como ✅. Nadie se entera: un cable suelto en
# Stimulus no tira error, no ensucia la consola, no rompe ninguna pantalla.
# Simplemente no suena — y el operario está mirando la pistola, no la pantalla.
#
# Este test lee las vistas y los controllers y los confronta.
class SonidosCableadosTest < ActiveSupport::TestCase
  VISTAS = Rails.root.glob("app/views/**/*.erb")
  CONTROLLERS_JS = Rails.root.join("app/javascript/controllers")
  AUDIO_JS = CONTROLLERS_JS.join("audio_controller.js")

  # `turbo:submit-end` y compañía los emite el framework, no un controller
  # nuestro: no tiene sentido buscarles un `dispatch`.
  PREFIJOS_AJENOS = %w[turbo window document click keydown change input submit].freeze

  test "cada evento cableado a un sonido tiene quien lo dispare" do
    huerfanos = cableados.filter_map do |vista, controller, evento, _accion|
      next if PREFIJOS_AJENOS.include?(controller)

      archivo = CONTROLLERS_JS.join("#{controller.tr('-', '_')}_controller.js")
      next "#{vista}: no existe #{archivo.basename}" unless archivo.exist?

      unless archivo.read.include?(%(dispatch("#{evento}")))
        "#{vista}: `#{controller}:#{evento}` — nadie hace dispatch(\"#{evento}\") en #{archivo.basename}"
      end
    end

    assert_empty huerfanos, "hay sonidos cableados que nunca van a sonar:\n#{huerfanos.join("\n")}"
  end

  test "cada accion de sonido nombra un metodo que existe" do
    # El otro lado del mismo cable: `audio#notifi` tampoco tira error, solo no
    # hace nada.
    metodos = AUDIO_JS.read.scan(/^  ([a-zA-Z_][\w]*)\s*\(/).flatten.to_set

    inventadas = cableados.filter_map do |vista, _controller, _evento, accion|
      "#{vista}: audio##{accion}" unless metodos.include?(accion)
    end

    assert_empty inventadas, "acciones de sonido que no existen en audio_controller.js:\n#{inventadas.join("\n")}"
  end

  # Las pantallas de escaneo: el operario está con la pistola y el paquete en
  # la mano, no leyendo. El diálogo de configuración de sonidos NO entra —ese
  # lo abre el operario con un clic, o sea que ya está mirando.
  CONTROLLERS_DE_ESCANEO = %w[etiquetar entrega_personal].freeze

  # Una línea que abre un modal: `showModal()`, o un target con "Modal" en el
  # nombre al que le sacan el `hidden`. Los banners no cuentan: se ven sin
  # tapar la pantalla.
  # Insensible a mayúsculas: el target del conflicto de sesión se llama
  # `conflictoSesionTarget`, con minúscula, y así no hay que acordarse de cómo
  # se escribió cada uno.
  ABRE_UN_MODAL = /\.showModal\(\)|(?:modal|conflictosesion)target\.classList\.remove\("hidden"\)/i

  # Un método de JS: `nombre() {` o `_nombre(args) {`. Se excluyen las
  # palabras del lenguaje para que un `if (...) {` no pase por método.
  ARRANQUE_DE_METODO = /^\s*(?!if\b|for\b|while\b|switch\b|catch\b|return\b)([A-Za-z_]\w*)\s*\([^)]*\)\s*\{\s*$/

  test "ningun modal de las pantallas de escaneo abre mudo" do
    # Yusef, A1-10: "un pin antes de que salga cualquier modal". El lint de
    # arriba solo prueba que ALGUIEN dispare el evento — con dos modales en el
    # mismo archivo, borrarle el sonido a uno lo dejaba pasar. Esto mira método
    # por método.
    mudos = CONTROLLERS_DE_ESCANEO.flat_map do |nombre|
      archivo = CONTROLLERS_JS.join("#{nombre}_controller.js")
      next [] unless archivo.exist?

      metodos_que_abren_modal(archivo.read)
        .reject { |_metodo, cuerpo| cuerpo.include?("this.dispatch(") }
        .map { |metodo, _cuerpo| "#{archivo.basename}##{metodo}" }
    end

    assert_empty mudos, "abren un modal sin hacer sonar nada:\n#{mudos.join("\n")}"
  end

  test "las dos pantallas con escaneo cablean el fallo del guardado" do
    # Un guardado que falla sin sonido es la misma trampa que el modal mudo.
    # /entrega_personal tenía solo `success`.
    sin_error = %w[etiquetar/index entrega_personal/new].reject do |vista|
      Rails.root.join("app/views/#{vista}.html.erb").read.include?("turbo:submit-end->audio#submitEnd")
    end

    assert_empty sin_error
  end

  private

  # { nombre del método => su cuerpo }, solo los que abren un modal.
  #
  # Partir por la firma del método y no por indentación: este archivo tiene
  # métodos a dos espacios y otros a cero, así que contar sangría no sirve.
  def metodos_que_abren_modal(src)
    actual = nil
    metodos = Hash.new { |h, k| h[k] = +"" }

    src.each_line do |linea|
      if (m = linea.match(ARRANQUE_DE_METODO))
        actual = m[1]
      end
      metodos[actual] << linea if actual
    end

    metodos.select { |_nombre, cuerpo| cuerpo.match?(ABRE_UN_MODAL) }
  end

  # [vista, controller, evento, accion] de cada `x:evento->audio#accion`.
  # Se escanea el archivo entero y no el atributo: los `data-action` de este
  # repo ocupan varias líneas y un regex por atributo se pierde.
  def cableados
    @cableados ||= VISTAS.flat_map do |archivo|
      archivo.read.scan(/([a-z][\w-]*):([A-Za-z][\w-]*)->audio#(\w+)/).map do |controller, evento, accion|
        [ archivo.relative_path_from(Rails.root).to_s, controller, evento, accion ]
      end
    end
  end
end
