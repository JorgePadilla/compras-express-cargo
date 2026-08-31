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

  # `date_field` cubre también `date_field_tag`; `datetime_field`, sus dos.
  LLAMADA_DE_FECHA = /\b(date_field|datetime_field|date_field_tag|datetime_field_tag)\b/

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
