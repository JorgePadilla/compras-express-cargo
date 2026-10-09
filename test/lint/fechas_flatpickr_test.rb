require "test_helper"

# Toda fecha del sistema usa **el date picker del proyecto**, no el del navegador.
#
# Jorge, 2026-08-30, mirando la pantalla del manifiesto: *"el date picker no es
# el que estamos usando en el proyecto"*. Eran ocho campos en cinco vistas los
# que habían quedado con el nativo (`yyyy-mm-dd` y el calendario que dibuja cada
# navegador a su manera).
#
# Importa más que la estética: `flatpickr_controller` va con `disableMobile:
# true` —que fuerza su propio calendario en vez del nativo de la tablet— y con
# `locale: Spanish` y formato `d/m/Y`. En una pantalla táctil, el picker nativo
# de Chrome en Android es la ruleta chiquita del sistema.
#
# Este lint existe porque la inconsistencia entró sola: nadie decidió que estas
# ocho fueran distintas, se fueron quedando. Sin algo que lo trabe, vuelve.
class FechasFlatpickrTest < ActiveSupport::TestCase
  VISTAS = Rails.root.join("app/views")

  # Las llamadas son multilínea, así que no sirve mirar línea por línea: se
  # corta el **tag ERB entero** —de `<%` a `%>`— y se busca adentro.
  TAG_ERB = /<%=?.*?%>/m

  # Todos los helpers que terminan dibujando un picker del navegador. La lista
  # arrancó con `date_field` y sus variantes, y le faltaba **`datetime_local_field`**:
  # `\bdate_field\b` no matchea adentro de `datetime_local_field` —la palabra es
  # otra—, así que el helper que más se parece al nativo era justo el que se
  # colaba. Hoy no hay ninguno escrito, y la idea es que siga así.
  HELPERS = %w[
    date_field date_field_tag
    datetime_field datetime_field_tag
    datetime_local_field datetime_local_field_tag
    time_field time_field_tag
    month_field month_field_tag
    week_field week_field_tag
  ].freeze
  LLAMADA_DE_FECHA = /\b(#{HELPERS.join("|")})\b/

  # Y el `<input>` escrito a mano, que no pasa por ningún helper.
  INPUT_CRUDO = /<input[^>]*\btype=["'](date|datetime-local|time|month|week)["'][^>]*>/i

  test "ningún <input type=date> escrito a mano se salta el picker" do
    sueltos = []

    Dir.glob(VISTAS.join("**/*.erb")).sort.each do |archivo|
      File.read(archivo).scan(INPUT_CRUDO) do
        tag = Regexp.last_match(0)
        next if tag.include?("flatpickr")

        sueltos << "#{Pathname.new(archivo).relative_path_from(Rails.root)}: #{tag[0, 90]}"
      end
    end

    assert_empty sueltos, "Estos `<input>` de fecha van sin el picker del proyecto:\n#{sueltos.join("\n")}"
  end

  test "la lista de helpers cubre las formas que Rails ofrece" do
    # `datetime_local_field` faltaba y no lo agarraba nadie. Este test fija la
    # lista para que agregar un helper nuevo sea una decisión, no un olvido.
    assert_includes HELPERS, "datetime_local_field",
                    "el que se colaba: `\\bdate_field\\b` no matchea adentro de `datetime_local_field`"
    assert_match LLAMADA_DE_FECHA, "f.datetime_local_field :cuando"
    assert_match LLAMADA_DE_FECHA, "date_field_tag :desde"
    refute_match LLAMADA_DE_FECHA, "f.text_field :fecha_a_mano",
                 "un campo de texto no es un picker nativo"
  end

  test "ninguna fecha usa el picker nativo del navegador" do
    sueltas = []

    Dir.glob(VISTAS.join("**/*.erb")).sort.each do |archivo|
      tags_de_fecha(File.read(archivo)).each do |tag|
        next if tag.include?("flatpickr")

        relativo = Pathname.new(archivo).relative_path_from(Rails.root)
        sueltas << "#{relativo}: #{tag.split("\n").first.strip}"
      end
    end

    assert_empty sueltas, <<~MSG
      Estas fechas usan el picker nativo del navegador:

      #{sueltas.join("\n      ")}

      Montá el del proyecto agregándole `data: { controller: "flatpickr" }`.
      El ejemplo más simple está en `app/views/paquetes/index.html.erb`; el que
      lleva además botón de limpiar, en `app/views/paquetes/_form.html.erb`.
    MSG
  end

  # El lint no sirve de nada si su propio regex dejó de enganchar — que es
  # exactamente cómo se murió en silencio un test de `pre_alertas`. Si un día
  # alguien renombra los helpers, este test avisa antes que el de arriba pase
  # vacío y contento.
  test "el lint de verdad encuentra fechas" do
    encontradas = Dir.glob(VISTAS.join("**/*.erb")).sum do |archivo|
      tags_de_fecha(File.read(archivo)).size
    end

    assert_operator encontradas, :>=, 9,
                    "el regex dejó de enganchar: había 9 campos de fecha en las vistas"
  end

  private

  # `scan` sin bloque devuelve los tags como strings —`TAG_ERB` no tiene grupos
  # de captura—, así que se filtran directo. La primera versión de esto usaba
  # `Regexp.last_match` adentro de un `count`, y devolvía cero: el lint pasaba
  # vacío y contento sin haber mirado un solo archivo. Lo cazó el test de acá
  # arriba, que es para lo que está.
  def tags_de_fecha(fuente)
    fuente.scan(TAG_ERB).select { |tag| tag.match?(LLAMADA_DE_FECHA) }
  end
end
