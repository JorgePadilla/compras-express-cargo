require "test_helper"

# PR-C29.11 · Todo lo que se aprieta en /medicion, del tamaño de un dedo.
#
# Jorge, 2026-10-08: *"all actionable in medicion should be easy to touch in a
# touch screen"*. La PESA es una laptop táctil (C27-13: *"tiene que ser touch
# en la pantalla"*), y Yusef ya lo había dicho de la X: *"una X grande, porque
# acordate que va a hacer touch"* (C29-14).
#
# 48 px es el piso: lo que da `ButtonComponent` en `size: :lg` (py-3 + línea
# de 24) y `min-h-12` en un campo. Este lint lee el ERB y no la pantalla
# porque la mitad de los botones vive en modales que un test de sistema
# tendría que abrir uno por uno; el de sistema
# (`medicion_dos_columnas_test`) mide lo que está a la vista.
class MedicionTactilTest < ActiveSupport::TestCase
  VISTA = Rails.root.join("app/views/medicion/index.html.erb")

  def fuente = @fuente ||= File.read(VISTA)

  def linea(match) = fuente[0, match.begin(0)].count("\n") + 1

  # Cada `ButtonComponent.new(…)` con sus argumentos completos —se cuentan
  # paréntesis, porque `data: { … }` y los `label:` con paréntesis rompen
  # cualquier regex— y si lleva contenido (`{ "texto" }` o `do`) o no.
  def botones
    @botones ||= fuente.to_enum(:scan, /ButtonComponent\.new\(/).map do
      inicio = Regexp.last_match.end(0)
      profundidad = 1
      i = inicio
      while profundidad.positive?
        profundidad += 1 if fuente[i] == "("
        profundidad -= 1 if fuente[i] == ")"
        i += 1
      end
      resto = fuente[i, 40].sub(/\A\)?\s*/, "")
      { args: fuente[inicio...(i - 1)], linea: fuente[0, inicio].count("\n") + 1,
        con_texto: resto.start_with?("{", "do") }
    end
  end

  test "todo ButtonComponent de /medicion es size: :lg" do
    assert_operator botones.size, :>, 20, "encontré #{botones.size} botones: el parser no está leyendo la vista"
    chicos = botones.reject { |b| b[:args].include?("size: :lg") }.map { |b| "medicion/index.html.erb:#{b[:linea]}" }

    assert_empty chicos, <<~MSG
      Estos botones de /medicion no son de dedo. En la PESA se aprieta con la
      mano en una pantalla táctil: `size: :lg` (48 px de alto), y si es de
      solo ícono, además `min-h-12 min-w-12`.
    MSG
  end

  test "los botones de solo ícono son cuadrados de 48" do
    solo_icono = botones.reject { |b| b[:con_texto] }
    assert solo_icono.any?, "no encontré botones de solo ícono: el test no mira nada"
    sin_tamano = solo_icono.reject { |b| b[:args].include?("min-h-12") && b[:args].include?("min-w-12") }
                           .map { |b| "medicion/index.html.erb:#{b[:linea]}" }

    assert_empty sin_tamano, "Un botón de solo ícono no tiene texto que lo agrande: necesita `min-h-12 min-w-12`."
  end

  test "todo campo de /medicion mide al menos 48 de alto" do
    campos = fuente.to_enum(:scan, /<%= (?:text_field_tag|number_field_tag|password_field_tag|select_tag)\b(.*?)%>/m).filter_map do
      llamada = Regexp.last_match(1)
      next if llamada.match?(/\bmin-h-(1[2-9]|[2-9]\d)\b/)

      "medicion/index.html.erb:#{linea(Regexp.last_match)}"
    end

    assert_empty campos, "Estos campos de /medicion miden menos de 48 px: `min-h-12` como mínimo."
  end

  test "las opciones de radio se tocan en todo el renglón" do
    radios = fuente.scan(/<label class="([^"]*)">\s*<%= radio_button_tag/)
    assert radios.any?, "no encontré los radios del descarte: el test no mira nada"
    radios.flatten.each do |clases|
      assert_match(/\bmin-h-12\b/, clases, "el renglón del radio tiene que medir 48 px: se toca la etiqueta entera")
    end
  end

  test "el botón de Sonidos sale en tamaño táctil" do
    assert_includes fuente, %(render("shared/sonido_config", tactil: true))
  end
end
